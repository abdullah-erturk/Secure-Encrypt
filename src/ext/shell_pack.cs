// Builds the files of the optional Windows 11 context menu entry: the icon file and an UNSIGNED sparse MSIX package
// (a ZIP with a block map; no Windows SDK needed). Used by SecureEncrypt.cmd when the menu entry is added.
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;

public static class ShellPack
{
    [DllImport("shell32.dll")]
    private static extern void SHChangeNotify(int eventId, uint flags, IntPtr item1, IntPtr item2);

    // tells Explorer that associations / handlers changed (SHCNE_ASSOCCHANGED), so that it reads the new menu entry now
    public static void NotifyShell()
    {
        SHChangeNotify(0x08000000, 0, IntPtr.Zero, IntPtr.Zero);
    }

    // the lock tile of the program, 28 design units
    private static Bitmap Draw(int px)
    {
        Bitmap bmp = new Bitmap(px, px, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(bmp))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.Clear(Color.Transparent);
            g.ScaleTransform(px / 28f, px / 28f);
            GraphicsPath p = new GraphicsPath();
            p.AddArc(0, 0, 16, 16, 180, 90); p.AddArc(12, 0, 16, 16, 270, 90);
            p.AddArc(12, 12, 16, 16, 0, 90); p.AddArc(0, 12, 16, 16, 90, 90);
            p.CloseFigure();
            using (LinearGradientBrush b = new LinearGradientBrush(new Rectangle(0, 0, 28, 28), Color.FromArgb(99, 102, 241), Color.FromArgb(56, 189, 248), 45f))
                g.FillPath(b, p);
            using (Pen pen = new Pen(Color.White, 2f))
            {
                g.DrawRectangle(pen, 9, 12, 10, 8);
                g.DrawArc(pen, 10, 5, 8, 10, 180, 180);
            }
        }
        return bmp;
    }

    private static byte[] Png(int px)
    {
        using (Bitmap b = Draw(px))
        using (MemoryStream ms = new MemoryStream())
        {
            b.Save(ms, ImageFormat.Png);
            return ms.ToArray();
        }
    }

    // classic ICO (32 bit bitmaps + mask): every Windows version reads it
    public static void WriteIco(string path)
    {
        int[] sizes = new int[] { 16, 20, 24, 32, 40, 48, 64 };
        List<byte[]> images = new List<byte[]>();
        foreach (int n in sizes)
        {
            byte[] pix = new byte[n * n * 4];
            using (Bitmap b = Draw(n))
            {
                BitmapData d = b.LockBits(new Rectangle(0, 0, n, n), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
                byte[] row = new byte[n * 4];
                for (int y = 0; y < n; y++)
                {
                    Marshal.Copy(new IntPtr(d.Scan0.ToInt64() + (long)y * d.Stride), row, 0, n * 4);
                    Array.Copy(row, 0, pix, (n - 1 - y) * n * 4, n * 4);
                }
                b.UnlockBits(d);
            }
            int maskRow = ((n + 31) / 32) * 4;
            using (MemoryStream ms = new MemoryStream())
            using (BinaryWriter w = new BinaryWriter(ms))
            {
                w.Write((uint)40); w.Write(n); w.Write(n * 2); w.Write((ushort)1); w.Write((ushort)32); w.Write((uint)0);
                w.Write((uint)(pix.Length + maskRow * n)); w.Write(0); w.Write(0); w.Write((uint)0); w.Write((uint)0);
                w.Write(pix);
                w.Write(new byte[maskRow * n]);
                images.Add(ms.ToArray());
            }
        }
        using (FileStream fs = new FileStream(path, FileMode.Create))
        using (BinaryWriter w = new BinaryWriter(fs))
        {
            w.Write((ushort)0); w.Write((ushort)1); w.Write((ushort)sizes.Length);
            int offset = 6 + 16 * sizes.Length;
            for (int i = 0; i < sizes.Length; i++)
            {
                w.Write((byte)sizes[i]); w.Write((byte)sizes[i]); w.Write((byte)0); w.Write((byte)0);
                w.Write((ushort)1); w.Write((ushort)32); w.Write((uint)images[i].Length); w.Write((uint)offset);
                offset += images[i].Length;
            }
            foreach (byte[] im in images) w.Write(im);
        }
    }

    // writes workDir\SecureEncrypt.msix and returns its path
    public static string Build(string workDir, string manifestText)
    {
        UTF8Encoding utf8 = new UTF8Encoding(false);
        MsixWriter w = new MsixWriter();
        w.Add("AppxManifest.xml", utf8.GetBytes(manifestText));
        w.Add("Assets/StoreLogo.png", Png(50));
        w.Add("Assets/Square44x44Logo.png", Png(44));
        w.Add("Assets/Square150x150Logo.png", Png(150));
        w.Add("AppxBlockMap.xml", utf8.GetBytes(w.BlockMap()));
        string ct = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"png\" ContentType=\"image/png\" /><Override PartName=\"/AppxManifest.xml\" ContentType=\"application/vnd.ms-appx.manifest+xml\" /><Override PartName=\"/AppxBlockMap.xml\" ContentType=\"application/vnd.ms-appx.blockmap+xml\" /></Types>";
        w.Add("[Content_Types].xml", utf8.GetBytes(ct));
        string path = Path.Combine(workDir, "SecureEncrypt.msix");
        w.Save(path);
        return path;
    }
}

// a ZIP whose entries are stored (not compressed), so the block map needs no compressed sizes
class MsixWriter
{
    private class Entry { public string Name; public byte[] Data; public uint Crc; public uint Offset; }
    private List<Entry> entries = new List<Entry>();
    private static uint[] table;

    private static uint Crc32(byte[] d)
    {
        if (table == null)
        {
            table = new uint[256];
            for (uint i = 0; i < 256; i++)
            {
                uint c = i;
                for (int k = 0; k < 8; k++) c = (c & 1) != 0 ? 0xEDB88320u ^ (c >> 1) : c >> 1;
                table[i] = c;
            }
        }
        uint crc = 0xFFFFFFFFu;
        for (int i = 0; i < d.Length; i++) crc = table[(crc ^ d[i]) & 0xFF] ^ (crc >> 8);
        return ~crc;
    }

    public void Add(string name, byte[] data)
    {
        Entry e = new Entry();
        e.Name = name; e.Data = data; e.Crc = Crc32(data);
        entries.Add(e);
    }

    // names inside the package use "/", the block map uses "\"; it lists every file added so far
    public string BlockMap()
    {
        StringBuilder sb = new StringBuilder();
        sb.Append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\r\n<BlockMap xmlns=\"http://schemas.microsoft.com/appx/2010/blockmap\" HashMethod=\"http://www.w3.org/2001/04/xmlenc#sha256\">");
        foreach (Entry e in entries)
        {
            int lfh = 30 + Encoding.UTF8.GetByteCount(e.Name);
            sb.Append("<File Name=\"" + e.Name.Replace('/', '\\') + "\" Size=\"" + e.Data.Length + "\" LfhSize=\"" + lfh + "\">");
            for (int off = 0; off < e.Data.Length; off += 65536)
            {
                int len = Math.Min(65536, e.Data.Length - off);
                byte[] blk = new byte[len];
                Array.Copy(e.Data, off, blk, 0, len);
                sb.Append("<Block Hash=\"" + Convert.ToBase64String(SHA256.Create().ComputeHash(blk)) + "\" />");
            }
            sb.Append("</File>");
        }
        sb.Append("</BlockMap>");
        return sb.ToString();
    }

    public void Save(string path)
    {
        using (FileStream fs = new FileStream(path, FileMode.Create))
        using (BinaryWriter w = new BinaryWriter(fs))
        {
            foreach (Entry e in entries)
            {
                e.Offset = (uint)fs.Position;
                byte[] n = Encoding.UTF8.GetBytes(e.Name);
                w.Write((uint)0x04034b50); w.Write((ushort)20); w.Write((ushort)0x0800); w.Write((ushort)0); w.Write((ushort)0); w.Write((ushort)0x21);
                w.Write(e.Crc); w.Write((uint)e.Data.Length); w.Write((uint)e.Data.Length); w.Write((ushort)n.Length); w.Write((ushort)0);
                w.Write(n); w.Write(e.Data);
            }
            uint cdStart = (uint)fs.Position;
            foreach (Entry e in entries)
            {
                byte[] n = Encoding.UTF8.GetBytes(e.Name);
                w.Write((uint)0x02014b50); w.Write((ushort)20); w.Write((ushort)20); w.Write((ushort)0x0800); w.Write((ushort)0); w.Write((ushort)0); w.Write((ushort)0x21);
                w.Write(e.Crc); w.Write((uint)e.Data.Length); w.Write((uint)e.Data.Length); w.Write((ushort)n.Length);
                w.Write((ushort)0); w.Write((ushort)0); w.Write((ushort)0); w.Write((ushort)0); w.Write((uint)0); w.Write(e.Offset); w.Write(n);
            }
            uint cdSize = (uint)fs.Position - cdStart;
            w.Write((uint)0x06054b50); w.Write((ushort)0); w.Write((ushort)0); w.Write((ushort)entries.Count); w.Write((ushort)entries.Count);
            w.Write(cdSize); w.Write(cdStart); w.Write((ushort)0);
        }
    }
}