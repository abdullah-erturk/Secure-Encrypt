using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Runtime.InteropServices;
using System.Security;
using System.Security.Cryptography;
using System.Text;

namespace SE
{
    public class Entry
    {
        public string Full;
        public string Rel;
        public bool IsDir;
        public long Length;
        public long MTime;
        public int Attr;

        public Entry(string full, string rel, bool isDir, long length, long mtime, int attr)
        {
            Full = full; Rel = rel; IsDir = isDir; Length = length; MTime = mtime; Attr = attr;
        }
    }

    public class ProgressBar
    {
        public static string Label = "";
        private long total;
        private long done;
        private int last = -1;

        public ProgressBar(long total) { this.total = total; Draw(); }

        public void Add(long n) { done += n; Draw(); }

        private void Draw()
        {
            int pct = total <= 0 ? 100 : (int)(done * 100 / total);
            if (pct > 100) pct = 100;
            if (pct == last) return;
            last = pct;
            int bar = pct * 30 / 100;
            Console.Write("\r" + Label + " [" + new string('=', bar) + new string(' ', 30 - bar) + "] " + pct + "%  ");
        }

        public void Finish() { done = total; Draw(); Console.WriteLine(); }
    }

    // ---- small stream helpers (no Stream.CopyTo etc., CLR 2.0 compatible) ----

    public abstract class BaseStream : Stream
    {
        public override bool CanRead { get { return false; } }
        public override bool CanSeek { get { return false; } }
        public override bool CanWrite { get { return false; } }
        public override long Length { get { throw new NotSupportedException(); } }
        public override long Position
        {
            get { throw new NotSupportedException(); }
            set { throw new NotSupportedException(); }
        }
        public override void Flush() { }
        public override long Seek(long offset, SeekOrigin origin) { throw new NotSupportedException(); }
        public override void SetLength(long value) { throw new NotSupportedException(); }
        public override int Read(byte[] buffer, int offset, int count) { throw new NotSupportedException(); }
        public override void Write(byte[] buffer, int offset, int count) { throw new NotSupportedException(); }
    }

    // Passes everything through but never closes the wrapped stream.
    public class NonClosingStream : BaseStream
    {
        private Stream s;
        public NonClosingStream(Stream s) { this.s = s; }
        public override bool CanRead { get { return s.CanRead; } }
        public override bool CanWrite { get { return s.CanWrite; } }
        public override int Read(byte[] b, int o, int c) { return s.Read(b, o, c); }
        public override void Write(byte[] b, int o, int c) { s.Write(b, o, c); }
        public override void Flush() { s.Flush(); }
    }

    public class HashWriteStream : BaseStream
    {
        private Stream inner;
        private HashAlgorithm h;
        public HashWriteStream(Stream inner, HashAlgorithm h) { this.inner = inner; this.h = h; }
        public override bool CanWrite { get { return true; } }
        public override void Write(byte[] b, int o, int c) { h.TransformBlock(b, o, c, null, 0); inner.Write(b, o, c); }
        public override void Flush() { inner.Flush(); }
        public byte[] Final() { h.TransformFinalBlock(new byte[0], 0, 0); return h.Hash; }
    }

    public class HashReadStream : BaseStream
    {
        private Stream inner;
        private HashAlgorithm h;
        public HashReadStream(Stream inner, HashAlgorithm h) { this.inner = inner; this.h = h; }
        public override bool CanRead { get { return true; } }
        public override int Read(byte[] b, int o, int c)
        {
            int n = inner.Read(b, o, c);
            if (n > 0) h.TransformBlock(b, o, n, null, 0);
            return n;
        }
        public byte[] Final() { h.TransformFinalBlock(new byte[0], 0, 0); return h.Hash; }
    }

    public class XorStream : BaseStream
    {
        private Stream inner;
        private byte[] key;
        private int idx;
        private byte[] tmp = new byte[0];

        public XorStream(Stream inner, byte[] key) { this.inner = inner; this.key = key; }
        public override bool CanRead { get { return inner.CanRead; } }
        public override bool CanWrite { get { return inner.CanWrite; } }
        public override void Flush() { inner.Flush(); }

        public override int Read(byte[] b, int o, int c)
        {
            int n = inner.Read(b, o, c);
            for (int i = 0; i < n; i++)
            {
                b[o + i] ^= key[idx];
                idx++;
                if (idx == key.Length) idx = 0;
            }
            return n;
        }

        public override void Write(byte[] b, int o, int c)
        {
            if (tmp.Length < c) tmp = new byte[c];
            for (int i = 0; i < c; i++)
            {
                tmp[i] = (byte)(b[o + i] ^ key[idx]);
                idx++;
                if (idx == key.Length) idx = 0;
            }
            inner.Write(tmp, 0, c);
        }
    }

    // Read-only window of at most 'remain' bytes from the current position.
    public class BoundedStream : BaseStream
    {
        private Stream s;
        private long remain;
        public BoundedStream(Stream s, long remain) { this.s = s; this.remain = remain; }
        public override bool CanRead { get { return true; } }
        public override int Read(byte[] b, int o, int c)
        {
            if (remain <= 0) return 0;
            int n = s.Read(b, o, (int)Math.Min((long)c, remain));
            remain -= n;
            return n;
        }
    }

    public static class Core
    {
        public const int DefaultIterations = 600000;
        public const string XorKeyText = "default_xor_key_for_text_obfuscation_secure_encrypt";
        private static readonly byte[] Magic = new byte[] { (byte)'S', (byte)'E', (byte)'v', (byte)'2' };
        private const int BufSize = 262144;

        // localizable texts, set from PowerShell
        public static string LblHash = "Hashing   ";
        public static string LblEncode = "Packing   ";
        public static string LblVerify = "Verifying ";
        public static string LblExtract = "Extracting";
        public static string LblKdf = "Deriving key...";
        public static string ConflictPrompt = "Already exists: {0}  [O]verwrite all / [R]ename / [S]kip all / [C]ancel:";
        public static int ConflictMode = 0; // 0 ask, 1 overwrite, 2 rename, 3 skip

        // results of the last Encode call
        public static string LastSha = "";
        public static long LastCount;
        public static long LastTotal;
        public static long LastOutSize;
        public static long LastDataStart;
        public static List<string> Skipped = new List<string>();

        // ------------------------------------------------------------ helpers

        public static byte[] XorKey()
        {
            return Encoding.ASCII.GetBytes(XorKeyText);
        }

        public static string ToHex(byte[] b)
        {
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < b.Length; i++) sb.Append(b[i].ToString("x2"));
            return sb.ToString();
        }

        internal static bool CompareBytes(byte[] a, byte[] b)
        {
            if (a.Length != b.Length) return false;
            int d = 0;
            for (int i = 0; i < a.Length; i++) d |= a[i] ^ b[i];
            return d == 0;
        }

        private static byte[] Rand(int n)
        {
            byte[] b = new byte[n];
            RNGCryptoServiceProvider r = new RNGCryptoServiceProvider();
            r.GetBytes(b);
            return b;
        }

        private static int ReadFully(Stream s, byte[] buf, int count)
        {
            int got = 0;
            while (got < count)
            {
                int n = s.Read(buf, got, count - got);
                if (n <= 0) break;
                got += n;
            }
            return got;
        }

        private static byte[] ReadExact(Stream s, int count)
        {
            byte[] b = new byte[count];
            if (ReadFully(s, b, count) != count) throw new InvalidDataException("FORMAT");
            return b;
        }

        private static char[] SecureChars(SecureString pw)
        {
            if (pw == null || pw.Length == 0) return new char[0];
            char[] c = new char[pw.Length];
            IntPtr p = Marshal.SecureStringToGlobalAllocUnicode(pw);
            try { Marshal.Copy(p, c, 0, c.Length); }
            finally { Marshal.ZeroFreeGlobalAllocUnicode(p); }
            return c;
        }

        public static bool SecureEquals(SecureString a, SecureString b)
        {
            char[] x = SecureChars(a);
            char[] y = SecureChars(b);
            bool ok = x.Length == y.Length;
            if (ok)
            {
                int d = 0;
                for (int i = 0; i < x.Length; i++) d |= x[i] ^ y[i];
                ok = d == 0;
            }
            Array.Clear(x, 0, x.Length);
            Array.Clear(y, 0, y.Length);
            return ok;
        }

        // 0 (very weak) .. 4 (strong)
        public static int Strength(SecureString pw)
        {
            char[] c = SecureChars(pw);
            int len = c.Length;
            bool lo = false, up = false, di = false, ot = false;
            for (int i = 0; i < c.Length; i++)
            {
                if (char.IsLower(c[i])) lo = true;
                else if (char.IsUpper(c[i])) up = true;
                else if (char.IsDigit(c[i])) di = true;
                else ot = true;
            }
            Array.Clear(c, 0, c.Length);
            int classes = (lo ? 1 : 0) + (up ? 1 : 0) + (di ? 1 : 0) + (ot ? 1 : 0);
            int score = 0;
            if (len >= 8) score++;
            if (len >= 12) score++;
            if (len >= 16) score++;
            if (len >= 20) score++;
            if (classes >= 3) score++;
            if (classes < 2 && len < 20 && score > 1) score = 1;
            if (score > 4) score = 4;
            return score;
        }

        public static byte[] HashFile(string path)
        {
            SHA256 sha = SHA256.Create();
            FileStream fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
            try
            {
                byte[] buf = new byte[BufSize];
                int n;
                while ((n = fs.Read(buf, 0, buf.Length)) > 0) sha.TransformBlock(buf, 0, n, null, 0);
                sha.TransformFinalBlock(new byte[0], 0, 0);
                return sha.Hash;
            }
            finally { fs.Close(); }
        }

        // password (UTF-8) + SHA-256 of the key file; null when neither is given
        public static byte[] MakeSecret(SecureString pw, string keyFile)
        {
            char[] chars = SecureChars(pw);
            byte[] pwBytes = Encoding.UTF8.GetBytes(chars);
            Array.Clear(chars, 0, chars.Length);
            byte[] kf = null;
            if (!string.IsNullOrEmpty(keyFile)) kf = HashFile(keyFile);
            if (pwBytes.Length == 0 && kf == null) return null;
            byte[] secret = new byte[pwBytes.Length + (kf == null ? 0 : 32)];
            Array.Copy(pwBytes, 0, secret, 0, pwBytes.Length);
            if (kf != null) Array.Copy(kf, 0, secret, pwBytes.Length, 32);
            Array.Clear(pwBytes, 0, pwBytes.Length);
            if (kf != null) Array.Clear(kf, 0, kf.Length);
            return secret;
        }

        // ------------------------------------------------------------ key derivation

        private static byte[] Pbkdf2(byte[] pwd, byte[] salt, int iter)
        {
            HMACSHA256 h = new HMACSHA256(pwd);
            try
            {
                byte[] s = new byte[salt.Length + 4];
                Array.Copy(salt, s, salt.Length);
                s[salt.Length + 3] = 1;
                byte[] u = h.ComputeHash(s);
                byte[] t = (byte[])u.Clone();
                for (int i = 1; i < iter; i++)
                {
                    u = h.ComputeHash(u);
                    for (int j = 0; j < t.Length; j++) t[j] ^= u[j];
                }
                return t;
            }
            finally { h.Clear(); }
        }

        private static byte[] Hmac(byte[] key, string label)
        {
            HMACSHA256 h = new HMACSHA256(key);
            try { return h.ComputeHash(Encoding.ASCII.GetBytes(label)); }
            finally { h.Clear(); }
        }

        internal static void DeriveKeys(byte[] secret, byte[] salt, int iter, out byte[] encKey, out byte[] macKey, out byte[] keyCheck)
        {
            Console.WriteLine(LblKdf);
            byte[] master = Pbkdf2(secret, salt, iter);
            encKey = Hmac(master, "SE2-ENC");
            macKey = Hmac(master, "SE2-MAC");
            byte[] kc = Hmac(macKey, "SE2-KEYCHECK");
            keyCheck = new byte[16];
            Array.Copy(kc, keyCheck, 16);
            Array.Clear(master, 0, master.Length);
        }

        private static RijndaelManaged NewAes(byte[] key, byte[] iv)
        {
            RijndaelManaged aes = new RijndaelManaged();
            aes.KeySize = 256;
            aes.BlockSize = 128;
            aes.Mode = CipherMode.CBC;
            aes.Padding = PaddingMode.PKCS7;
            aes.Key = key;
            aes.IV = iv;
            return aes;
        }

        // ------------------------------------------------------------ collecting

        private static bool SamePath(string a, string b)
        {
            return b != null && string.Equals(a, b, StringComparison.OrdinalIgnoreCase);
        }

        private static void AddDir(string dir, string rel, List<Entry> list, List<string> skipped, string ex1, string ex2)
        {
            int before = list.Count;
            string[] files = new string[0];
            try { files = Directory.GetFiles(dir); }
            catch { skipped.Add(dir); }
            for (int i = 0; i < files.Length; i++)
            {
                string f = files[i];
                if (SamePath(f, ex1) || SamePath(f, ex2)) continue;
                try
                {
                    FileInfo fi = new FileInfo(f);
                    list.Add(new Entry(f, rel + "/" + fi.Name, false, fi.Length,
                        fi.LastWriteTimeUtc.ToFileTimeUtc(), (int)fi.Attributes & 0x27));
                }
                catch { skipped.Add(f); }
            }
            string[] dirs = new string[0];
            try { dirs = Directory.GetDirectories(dir); }
            catch { skipped.Add(dir); }
            for (int i = 0; i < dirs.Length; i++)
            {
                string d = dirs[i];
                string name = Path.GetFileName(d);
                if (string.Equals(name, "System Volume Information", StringComparison.OrdinalIgnoreCase) ||
                    string.Equals(name, "$RECYCLE.BIN", StringComparison.OrdinalIgnoreCase)) continue;
                try
                {
                    if ((File.GetAttributes(d) & FileAttributes.ReparsePoint) != 0) { skipped.Add(d); continue; }
                }
                catch { skipped.Add(d); continue; }
                AddDir(d, rel + "/" + name, list, skipped, ex1, ex2);
            }
            if (list.Count == before)
            {
                DateTime t = DateTime.UtcNow;
                int a = 0;
                try { t = Directory.GetLastWriteTimeUtc(dir); a = (int)File.GetAttributes(dir) & 0x27; } catch { }
                list.Add(new Entry(dir, rel, true, 0, t.ToFileTimeUtc(), a));
            }
        }

        private static List<Entry> Collect(string[] items, List<string> skipped, string ex1, string ex2)
        {
            List<Entry> list = new List<Entry>();
            for (int i = 0; i < items.Length; i++)
            {
                string full = Path.GetFullPath(items[i]);
                if (Directory.Exists(full))
                {
                    string trimmed = full.TrimEnd('\\');
                    string name = Path.GetFileName(trimmed);
                    if (name.Length == 0) name = "Drive_" + full.Substring(0, 1);
                    AddDir(full, name, list, skipped, ex1, ex2);
                }
                else
                {
                    FileInfo fi = new FileInfo(full);
                    list.Add(new Entry(full, fi.Name, false, fi.Length,
                        fi.LastWriteTimeUtc.ToFileTimeUtc(), (int)fi.Attributes & 0x27));
                }
            }
            return list;
        }

        // ------------------------------------------------------------ container (write)

        private static void WriteContainer(List<Entry> entries, long total, Stream dest, ProgressBar pb)
        {
            BinaryWriter bw = new BinaryWriter(dest, Encoding.UTF8);
            bw.Write(new byte[] { (byte)'S', (byte)'E', (byte)'C', (byte)'1' });
            bw.Write(entries.Count);
            bw.Write(total);
            byte[] buf = new byte[BufSize];
            for (int i = 0; i < entries.Count; i++)
            {
                Entry e = entries[i];
                bw.Write((byte)(e.IsDir ? 1 : 0));
                bw.Write(e.Rel);
                bw.Write(e.MTime);
                bw.Write(e.Attr);
                if (e.IsDir) continue;
                bw.Write(e.Length);
                long left = e.Length;
                FileStream fs = new FileStream(e.Full, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
                try
                {
                    while (left > 0)
                    {
                        int n = fs.Read(buf, 0, (int)Math.Min((long)buf.Length, left));
                        if (n <= 0) throw new IOException("CHANGED");
                        dest.Write(buf, 0, n);
                        left -= n;
                        if (pb != null) pb.Add(n);
                    }
                }
                finally { fs.Close(); }
            }
            bw.Flush();
        }

        // Writes [sha32][gzip?(container)] into sink, returns SHA-256 of the container bytes.
        private static byte[] WritePayload(List<Entry> entries, long total, Stream sink, bool gzip, byte[] prefixSha, ProgressBar pb)
        {
            if (prefixSha != null) sink.Write(prefixSha, 0, prefixSha.Length);
            Stream dst = sink;
            GZipStream gz = null;
            if (gzip) { gz = new GZipStream(sink, CompressionMode.Compress, true); dst = gz; }
            HashWriteStream hs = new HashWriteStream(dst, SHA256.Create());
            WriteContainer(entries, total, hs, pb);
            hs.Flush();
            if (gz != null) gz.Close();
            return hs.Final();
        }

        // ------------------------------------------------------------ Encode

        // Appends the payload to 'outPath' (which already holds the text part of the .cmd).
        // secret == null  -> compressed + XOR obfuscated (mode 1), otherwise AES-256-CBC + HMAC-SHA256 (mode 2).
        public static void Encode(string[] items, string outPath, string alsoExclude, bool gzip, byte[] secret,
                                  bool usesPassword, bool usesKeyFile, int iterations, bool verify)
        {
            List<string> skipped = new List<string>();
            List<Entry> entries = Collect(items, skipped, outPath, alsoExclude);
            Skipped = skipped;
            if (entries.Count == 0) throw new InvalidOperationException("EMPTY");
            long total = 0;
            for (int i = 0; i < entries.Count; i++) total += entries[i].Length;
            LastCount = entries.Count;
            LastTotal = total;

            // pass 1: hash of the container
            ProgressBar.Label = LblHash;
            ProgressBar pb1 = new ProgressBar(total);
            HashWriteStream h1 = new HashWriteStream(Stream.Null, SHA256.Create());
            WriteContainer(entries, total, h1, pb1);
            byte[] sha = h1.Final();
            pb1.Finish();
            LastSha = ToHex(sha);

            int mode = secret == null ? 1 : 2;
            int flags = (gzip ? 1 : 0) | (usesPassword ? 2 : 0) | (usesKeyFile ? 4 : 0);

            FileStream fo = new FileStream(outPath, FileMode.Append, FileAccess.Write, FileShare.None);
            byte[] sha2;
            try
            {
                LastDataStart = fo.Position;
                ProgressBar.Label = LblEncode;
                if (mode == 1)
                {
                    fo.Write(Magic, 0, 4);
                    fo.WriteByte(1);
                    fo.WriteByte((byte)flags);
                    fo.Write(sha, 0, 32);
                    ProgressBar pb2 = new ProgressBar(total);
                    XorStream xs = new XorStream(new NonClosingStream(fo), XorKey());
                    sha2 = WritePayload(entries, total, xs, gzip, null, pb2);
                    xs.Flush();
                    pb2.Finish();
                }
                else
                {
                    byte[] salt = Rand(16);
                    byte[] iv = Rand(16);
                    byte[] encKey, macKey, kc;
                    DeriveKeys(secret, salt, iterations, out encKey, out macKey, out kc);
                    byte[] header = new byte[58];
                    Array.Copy(Magic, 0, header, 0, 4);
                    header[4] = 2;
                    header[5] = (byte)flags;
                    header[6] = (byte)(iterations & 0xFF);
                    header[7] = (byte)((iterations >> 8) & 0xFF);
                    header[8] = (byte)((iterations >> 16) & 0xFF);
                    header[9] = (byte)((iterations >> 24) & 0xFF);
                    Array.Copy(salt, 0, header, 10, 16);
                    Array.Copy(iv, 0, header, 26, 16);
                    Array.Copy(kc, 0, header, 42, 16);
                    HMACSHA256 mac = new HMACSHA256(macKey);
                    HashWriteStream hw = new HashWriteStream(fo, mac);
                    hw.Write(header, 0, header.Length);
                    RijndaelManaged aes = NewAes(encKey, iv);
                    CryptoStream cs = new CryptoStream(new NonClosingStream(hw), aes.CreateEncryptor(), CryptoStreamMode.Write);
                    ProgressBar pb2 = new ProgressBar(total);
                    sha2 = WritePayload(entries, total, cs, gzip, sha, pb2);
                    cs.FlushFinalBlock();
                    cs.Close();
                    pb2.Finish();
                    byte[] tag = hw.Final();
                    fo.Write(tag, 0, tag.Length);
                    aes.Clear();
                    Array.Clear(encKey, 0, encKey.Length);
                    Array.Clear(macKey, 0, macKey.Length);
                }
                fo.Flush();
                LastOutSize = fo.Length;
            }
            finally { fo.Close(); }

            if (!CompareBytes(sha, sha2)) throw new IOException("CHANGED");

            if (verify)
            {
                ProgressBar.Label = LblVerify;
                Archive a = Archive.Open(outPath, LastDataStart);
                try
                {
                    if (!a.Unlock(secret)) throw new CryptographicException("VERIFY");
                    a.Extract(null);
                    if (!a.ShaOk) throw new CryptographicException("VERIFY");
                }
                finally { a.Clear(); }
            }
        }

        // ------------------------------------------------------------ deleting originals

        private static void DeleteFile(string f, bool overwrite)
        {
            File.SetAttributes(f, FileAttributes.Normal);
            if (overwrite)
            {
                long left = new FileInfo(f).Length;
                FileStream fs = new FileStream(f, FileMode.Open, FileAccess.Write, FileShare.None);
                try
                {
                    byte[] b = new byte[65536];
                    RNGCryptoServiceProvider r = new RNGCryptoServiceProvider();
                    while (left > 0)
                    {
                        r.GetBytes(b);
                        int n = (int)Math.Min((long)b.Length, left);
                        fs.Write(b, 0, n);
                        left -= n;
                    }
                    fs.Flush();
                }
                finally { fs.Close(); }
            }
            File.Delete(f);
        }

        // items that could not be deleted (path : reason) after the last DeleteItems call
        public static List<string> DeleteFailed = new List<string>();

        private static void TryDeleteFile(string f, bool overwrite)
        {
            try { DeleteFile(f, overwrite); }
            catch (Exception ex) { DeleteFailed.Add(f + " : " + ex.Message); }
        }

        private static void DeleteDir(string d, bool overwrite)
        {
            string[] files = new string[0];
            string[] dirs = new string[0];
            try { files = Directory.GetFiles(d); dirs = Directory.GetDirectories(d); }
            catch (Exception ex) { DeleteFailed.Add(d + " : " + ex.Message); return; }
            for (int i = 0; i < files.Length; i++) TryDeleteFile(files[i], overwrite);
            for (int i = 0; i < dirs.Length; i++) DeleteDir(dirs[i], overwrite);
            try
            {
                File.SetAttributes(d, FileAttributes.Normal);
                Directory.Delete(d);
            }
            catch (Exception ex) { DeleteFailed.Add(d + " : " + ex.Message); }
        }

        // Keeps going after a failure so that one locked file does not leave the rest behind.
        public static void DeleteItems(string[] items, bool overwrite)
        {
            DeleteFailed = new List<string>();
            for (int i = 0; i < items.Length; i++)
            {
                if (Directory.Exists(items[i])) DeleteDir(items[i], overwrite);
                else TryDeleteFile(items[i], overwrite);
            }
        }
        // ------------------------------------------------------------ extraction helpers

        private static string SafePath(string root, string rel)
        {
            string r = rel.Replace('/', '\\');
            if (r.Length == 0 || r.IndexOf(':') >= 0 || r[0] == '\\') throw new InvalidDataException("PATH");
            string[] parts = r.Split('\\');
            for (int i = 0; i < parts.Length; i++)
                if (parts[i].Length == 0 || parts[i] == ".." || parts[i] == ".") throw new InvalidDataException("PATH");
            string full = Path.GetFullPath(Path.Combine(root, r));
            if (!full.StartsWith(root, StringComparison.OrdinalIgnoreCase)) throw new InvalidDataException("PATH");
            return full;
        }

        private static string UniqueName(string path)
        {
            string dir = Path.GetDirectoryName(path);
            string name = Path.GetFileNameWithoutExtension(path);
            string ext = Path.GetExtension(path);
            for (int i = 1; ; i++)
            {
                string cand = Path.Combine(dir, name + " (" + i + ")" + ext);
                if (!File.Exists(cand) && !Directory.Exists(cand)) return cand;
            }
        }

        private static int Conflict(string target)
        {
            if (ConflictMode == 0)
            {
                Console.WriteLine();
                while (true)
                {
                    Console.Write(ConflictPrompt.Replace("{0}", target) + " ");
                    string a = Console.ReadLine();
                    if (a == null) throw new OperationCanceledException();
                    a = a.Trim().ToLowerInvariant();
                    if (a == "o") ConflictMode = 1;
                    else if (a == "r") ConflictMode = 2;
                    else if (a == "s") ConflictMode = 3;
                    else if (a == "c") throw new OperationCanceledException();
                    else continue;
                    break;
                }
            }
            return ConflictMode;
        }

        internal static void ExtractContainer(Stream s, string destDir, out long count, out long total)
        {
            BinaryReader br = new BinaryReader(s, Encoding.UTF8);
            byte[] m = br.ReadBytes(4);
            if (m.Length != 4 || m[0] != 'S' || m[1] != 'E' || m[2] != 'C' || m[3] != '1') throw new InvalidDataException("FORMAT");
            int n = br.ReadInt32();
            total = br.ReadInt64();
            count = n;
            if (n < 0 || total < 0) throw new InvalidDataException("FORMAT");

            string root = null;
            if (destDir != null)
            {
                root = Path.GetFullPath(destDir);
                if (!root.EndsWith("\\")) root += "\\";
                Directory.CreateDirectory(root);
            }

            ProgressBar pb = new ProgressBar(total);
            byte[] buf = new byte[BufSize];
            for (int i = 0; i < n; i++)
            {
                int type = br.ReadByte();
                string rel = br.ReadString();
                long mt = br.ReadInt64();
                int attr = br.ReadInt32();
                string target = root == null ? null : SafePath(root, rel);

                if (type == 1)
                {
                    if (target != null)
                    {
                        if (File.Exists(target)) throw new IOException("EXISTS");
                        Directory.CreateDirectory(target);
                    }
                    continue;
                }

                long len = br.ReadInt64();
                if (len < 0) throw new InvalidDataException("FORMAT");
                if (target != null && (File.Exists(target) || Directory.Exists(target)))
                {
                    int act = Conflict(target);
                    if (act == 2) target = UniqueName(target);
                    else if (act == 3) target = null;
                }

                FileStream fo = null;
                if (target != null)
                {
                    Directory.CreateDirectory(Path.GetDirectoryName(target));
                    if (File.Exists(target)) File.SetAttributes(target, FileAttributes.Normal);
                    fo = new FileStream(target, FileMode.Create, FileAccess.Write, FileShare.None);
                }
                try
                {
                    long left = len;
                    while (left > 0)
                    {
                        int r = s.Read(buf, 0, (int)Math.Min((long)buf.Length, left));
                        if (r <= 0) throw new InvalidDataException("FORMAT");
                        if (fo != null) fo.Write(buf, 0, r);
                        left -= r;
                        pb.Add(r);
                    }
                }
                finally { if (fo != null) fo.Close(); }

                if (target != null)
                {
                    try
                    {
                        File.SetLastWriteTimeUtc(target, DateTime.FromFileTimeUtc(mt));
                        File.SetAttributes(target, (FileAttributes)(attr & 0x27));
                    }
                    catch { }
                }
            }
            pb.Finish();
        }
    }

    public class Archive
    {
        public int Mode;
        public int Flags;
        public int Iterations;
        public byte[] HeaderSha;
        public bool ShaOk;
        public string ShaHex = "";
        public long Count;
        public long Total;

        private string path;
        private long dataStart;
        private long payloadStart;
        private long payloadEnd;
        private byte[] salt;
        private byte[] iv;
        private byte[] keyCheck;
        private byte[] encKey;
        private byte[] macKey;

        // upper limit for the iteration count read from a file (checked before anything is authenticated)
        public const int MaxIterations = 10000000;

        // wipes the derived keys; Extract cannot be used afterwards
        public void Clear()
        {
            if (encKey != null) Array.Clear(encKey, 0, encKey.Length);
            if (macKey != null) Array.Clear(macKey, 0, macKey.Length);
            encKey = null;
            macKey = null;
        }

        public bool IsGzip { get { return (Flags & 1) != 0; } }
        public bool UsesPassword { get { return (Flags & 2) != 0; } }
        public bool UsesKeyFile { get { return (Flags & 4) != 0; } }

        public static Archive Open(string path, long dataStart)
        {
            Archive a = new Archive();
            a.path = path;
            a.dataStart = dataStart;
            FileStream fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
            try
            {
                long len = fs.Length;
                fs.Position = dataStart;
                byte[] h = new byte[6];
                if (ReadHeader(fs, h, 6) != 6 || h[0] != 'S' || h[1] != 'E' || h[2] != 'v' || h[3] != '2')
                    throw new InvalidDataException("FORMAT");
                a.Mode = h[4];
                a.Flags = h[5];
                if (a.Mode == 1)
                {
                    a.HeaderSha = new byte[32];
                    if (ReadHeader(fs, a.HeaderSha, 32) != 32) throw new InvalidDataException("FORMAT");
                    a.payloadStart = dataStart + 38;
                    a.payloadEnd = len;
                }
                else if (a.Mode == 2)
                {
                    byte[] r = new byte[52];
                    if (ReadHeader(fs, r, 52) != 52) throw new InvalidDataException("FORMAT");
                    a.Iterations = r[0] | (r[1] << 8) | (r[2] << 16) | (r[3] << 24);
                    if (a.Iterations < 1000 || a.Iterations > MaxIterations) throw new InvalidDataException("FORMAT");
                    a.salt = new byte[16]; Array.Copy(r, 4, a.salt, 0, 16);
                    a.iv = new byte[16]; Array.Copy(r, 20, a.iv, 0, 16);
                    a.keyCheck = new byte[16]; Array.Copy(r, 36, a.keyCheck, 0, 16);
                    a.payloadStart = dataStart + 58;
                    a.payloadEnd = len - 32;
                    if (a.payloadEnd < a.payloadStart) throw new InvalidDataException("FORMAT");
                }
                else throw new InvalidDataException("FORMAT");
            }
            finally { fs.Close(); }
            return a;
        }

        private static int ReadHeader(Stream s, byte[] b, int count)
        {
            int got = 0;
            while (got < count)
            {
                int n = s.Read(b, got, count - got);
                if (n <= 0) break;
                got += n;
            }
            return got;
        }

        // Derives the keys and checks them against the stored key check value.
        public bool Unlock(byte[] secret)
        {
            if (Mode != 2) return true;
            byte[] ek, mk, kc;
            Core.DeriveKeys(secret, salt, Iterations, out ek, out mk, out kc);
            bool ok = Core.CompareBytes(kc, keyCheck);
            if (ok) { encKey = ek; macKey = mk; }
            else { Array.Clear(ek, 0, ek.Length); Array.Clear(mk, 0, mk.Length); }
            return ok;
        }

        // destDir == null: decode and verify only, write nothing.
        public void Extract(string destDir)
        {
            FileStream fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
            try
            {
                Stream src;
                byte[] expected;
                if (Mode == 2)
                {
                    if (macKey == null) throw new InvalidOperationException("LOCKED");
                    ProgressBar.Label = Core.LblVerify;
                    ProgressBar pbm = new ProgressBar(payloadEnd - dataStart);
                    HMACSHA256 mac = new HMACSHA256(macKey);
                    fs.Position = dataStart;
                    byte[] buf = new byte[262144];
                    long left = payloadEnd - dataStart;
                    while (left > 0)
                    {
                        int n = fs.Read(buf, 0, (int)Math.Min((long)buf.Length, left));
                        if (n <= 0) throw new InvalidDataException("FORMAT");
                        mac.TransformBlock(buf, 0, n, null, 0);
                        left -= n;
                        pbm.Add(n);
                    }
                    mac.TransformFinalBlock(new byte[0], 0, 0);
                    pbm.Finish();
                    byte[] tag = new byte[32];
                    if (ReadHeader(fs, tag, 32) != 32) throw new InvalidDataException("FORMAT");
                    if (!Core.CompareBytes(mac.Hash, tag)) throw new CryptographicException("MAC");

                    fs.Position = payloadStart;
                    RijndaelManaged aes = new RijndaelManaged();
                    aes.KeySize = 256;
                    aes.BlockSize = 128;
                    aes.Mode = CipherMode.CBC;
                    aes.Padding = PaddingMode.PKCS7;
                    aes.Key = encKey;
                    aes.IV = iv;
                    CryptoStream cs = new CryptoStream(new BoundedStream(fs, payloadEnd - payloadStart), aes.CreateDecryptor(), CryptoStreamMode.Read);
                    expected = new byte[32];
                    if (ReadHeader(cs, expected, 32) != 32) throw new InvalidDataException("FORMAT");
                    src = cs;
                }
                else
                {
                    fs.Position = payloadStart;
                    src = new XorStream(new BoundedStream(fs, payloadEnd - payloadStart), Core.XorKey());
                    expected = HeaderSha;
                }
                if (IsGzip) src = new GZipStream(src, CompressionMode.Decompress);

                ProgressBar.Label = destDir == null ? Core.LblVerify : Core.LblExtract;
                HashReadStream hr = new HashReadStream(src, SHA256.Create());
                long count, total;
                Core.ExtractContainer(hr, destDir, out count, out total);
                Count = count;
                Total = total;
                byte[] drain = new byte[4096];
                while (hr.Read(drain, 0, drain.Length) > 0) { }
                byte[] actual = hr.Final();
                ShaHex = Core.ToHex(actual);
                ShaOk = Core.CompareBytes(actual, expected);
            }
            finally { fs.Close(); }
        }
    }
}
