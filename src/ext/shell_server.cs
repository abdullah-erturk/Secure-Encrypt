// SecureEncrypt entries for the Windows 11 context menu: a small out-of-process COM server (IExplorerCommand).
// Explorer starts it with -Embedding when the menu is shown or an entry is clicked.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Reflection;

[assembly: AssemblyTitle("SecureEncrypt Windows 11 context menu handler")]
[assembly: AssemblyDescription("SecureEncrypt Windows 11 context menu handler")]
[assembly: AssemblyCompany("Abdullah ERTÜRK")]
[assembly: AssemblyProduct("SecureEncrypt")]
[assembly: AssemblyCopyright("Open source - Abdullah ERTÜRK - github.com/abdullah-erturk - erturk-dev.netlify.app")]
[assembly: AssemblyVersion("8.0.0.0")]
[assembly: AssemblyFileVersion("8.0.0.0")]
[assembly: AssemblyInformationalVersion("8.0 -open source: github.com/abdullah-erturk - erturk-dev.netlify.app")]

namespace SEShell
{
    [ComImport, Guid("43826d1e-e718-42ee-bc55-a1e261c37bfe"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IShellItem
    {
        void BindToHandler(IntPtr pbc, ref Guid bhid, ref Guid riid, out IntPtr ppv);
        void GetParent(out IShellItem ppsi);
        void GetDisplayName(uint sigdnName, out IntPtr ppszName);
        void GetAttributes(uint mask, out uint attr);
        void Compare(IShellItem psi, uint hint, out int order);
    }

    [ComImport, Guid("b63ea76d-1f85-456f-a19c-48159efa858b"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IShellItemArray
    {
        void BindToHandler(IntPtr pbc, ref Guid bhid, ref Guid riid, out IntPtr ppvOut);
        void GetPropertyStore(int flags, ref Guid riid, out IntPtr ppv);
        void GetPropertyDescriptionList(IntPtr keyType, ref Guid riid, out IntPtr ppv);
        void GetAttributes(int attribFlags, uint sfgaoMask, out uint attribs);
        void GetCount(out uint count);
        void GetItemAt(uint index, out IShellItem item);
        void EnumItems(out IntPtr enumItems);
    }

    [ComImport, Guid("a08ce4d0-fa25-44ab-b57c-c7b1c323e0b9"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IExplorerCommand
    {
        [PreserveSig] int GetTitle(IShellItemArray items, [MarshalAs(UnmanagedType.LPWStr)] out string name);
        [PreserveSig] int GetIcon(IShellItemArray items, [MarshalAs(UnmanagedType.LPWStr)] out string icon);
        [PreserveSig] int GetToolTip(IShellItemArray items, [MarshalAs(UnmanagedType.LPWStr)] out string tip);
        [PreserveSig] int GetCanonicalName(out Guid guid);
        [PreserveSig] int GetState(IShellItemArray items, [MarshalAs(UnmanagedType.Bool)] bool okToBeSlow, out uint state);
        [PreserveSig] int Invoke(IShellItemArray items, IntPtr bindCtx);
        [PreserveSig] int GetFlags(out uint flags);
        [PreserveSig] int EnumSubCommands(out IntPtr enumCommands);
    }

    [ComImport, Guid("a88826f8-186f-4987-aade-ea0cef8fbfe8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IEnumExplorerCommand
    {
        [PreserveSig] int Next(uint celt, [Out, MarshalAs(UnmanagedType.LPArray, ArraySubType = UnmanagedType.Interface, SizeParamIndex = 0)] IExplorerCommand[] commands, out uint fetched);
        [PreserveSig] int Skip(uint celt);
        [PreserveSig] int Reset();
        [PreserveSig] int Clone(out IEnumExplorerCommand clone);
    }

    [ComImport, Guid("00000001-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IClassFactory
    {
        [PreserveSig] int CreateInstance(IntPtr outer, ref Guid riid, out IntPtr obj);
        [PreserveSig] int LockServer([MarshalAs(UnmanagedType.Bool)] bool lockServer);
    }

    [ComImport, Guid("FC4801A3-2BA9-11CF-A229-00AA003D7352"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IObjectWithSite
    {
        [PreserveSig] int SetSite([MarshalAs(UnmanagedType.IUnknown)] object site);
        [PreserveSig] int GetSite(ref Guid riid, out IntPtr site);
    }

    static class SiteInfo
    {
        // Explorer hosts a verb of a packaged app in two places: its new (short) menu and the old menu ("Show more options").
        // In the old menu the site object is the context menu host and supports IContextMenu; in the new menu it does not.
        public static bool IsClassicMenu(object site)
        {
            if (site == null) return false;
            IntPtr unk = IntPtr.Zero, p = IntPtr.Zero;
            try
            {
                unk = Marshal.GetIUnknownForObject(site);
                Guid g = new Guid("000214E4-0000-0000-C000-000000000046");     // IContextMenu
                if (Marshal.QueryInterface(unk, ref g, out p) == 0) { Marshal.Release(p); return true; }
            }
            catch { }
            finally { if (unk != IntPtr.Zero) Marshal.Release(unk); }
            return false;
        }
    }

    static class Util
    {
        public static DateTime Last = DateTime.UtcNow;
        public static void Touch() { Last = DateTime.UtcNow; }

        public static List<string> Paths(IShellItemArray items)
        {
            List<string> r = new List<string>();
            if (items == null) return r;
            uint n;
            items.GetCount(out n);
            for (uint i = 0; i < n; i++)
            {
                IShellItem it;
                items.GetItemAt(i, out it);
                IntPtr p;
                it.GetDisplayName(0x80058000, out p);                  // SIGDN_FILESYSPATH
                string s = Marshal.PtrToStringUni(p);
                Marshal.FreeCoTaskMem(p);
                if (!string.IsNullOrEmpty(s)) r.Add(s);
            }
            return r;
        }

        // the texts come from labels.txt next to this program (written by the installer in the current language)
        public static string Label(int line, string fallback)
        {
            try
            {
                string f = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "labels.txt");
                if (File.Exists(f))
                {
                    string[] l = File.ReadAllLines(f, Encoding.UTF8);
                    if (l.Length > line && l[line].Trim().Length > 0) return l[line].Trim();
                }
            }
            catch { }
            return fallback;
        }

        // our own icon file next to this program (the lock tile); the system icon is the fallback
        public static string IconPath()
        {
            string f = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "SecureEncrypt.ico");
            if (File.Exists(f)) return f;
            return Environment.GetFolderPath(Environment.SpecialFolder.System) + "\\imageres.dll,54";
        }

        public static string Target()
        {
            return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), "SecureEncrypt.cmd");
        }
    }

    [ComVisible(true), ClassInterface(ClassInterfaceType.None)]
    class EncryptCommand : IExplorerCommand
    {
        public int GetTitle(IShellItemArray items, out string name) { Util.Touch(); name = Util.Label(0, "Encrypt (Secure Encrypt AES-256)"); return 0; }
        public int GetIcon(IShellItemArray items, out string icon) { icon = Util.IconPath(); return 0; }
        public int GetToolTip(IShellItemArray items, out string tip) { tip = null; return unchecked((int)0x80004001); }
        public int GetCanonicalName(out Guid guid) { guid = Guid.Empty; return unchecked((int)0x80004001); }
        public int GetState(IShellItemArray items, bool okToBeSlow, out uint state) { Util.Touch(); state = 0; return 0; }
        public int GetFlags(out uint flags) { flags = 0; return 0; }
        public int EnumSubCommands(out IntPtr e) { e = IntPtr.Zero; return unchecked((int)0x80004001); }

        public int Invoke(IShellItemArray items, IntPtr bindCtx)
        {
            Util.Touch();
            try
            {
                List<string> paths = Util.Paths(items);
                if (paths.Count == 0) return 0;
                string q = Path.Combine(Path.GetTempPath(), "SecureEncrypt_queue");
                Directory.CreateDirectory(q);
                string list = Path.Combine(q, "list_" + DateTime.UtcNow.Ticks + "_" + Guid.NewGuid().ToString("N").Substring(0, 6) + ".txt");
                File.WriteAllText(list, string.Join("\r\n", paths.ToArray()), Encoding.Unicode);
                ProcessStartInfo psi = new ProcessStartInfo(Util.Target(), "/list \"" + list + "\"");
                psi.UseShellExecute = true;
                Process.Start(psi);
            }
            catch { }
            return 0;
        }
    }

    [ComVisible(true), ClassInterface(ClassInterfaceType.None)]
    class DecryptCommand : IExplorerCommand
    {
        public int GetTitle(IShellItemArray items, out string name) { Util.Touch(); name = Util.Label(1, "Decrypt (Secure Encrypt AES-256)"); return 0; }
        public int GetIcon(IShellItemArray items, out string icon) { icon = Util.IconPath(); return 0; }
        public int GetToolTip(IShellItemArray items, out string tip) { tip = null; return unchecked((int)0x80004001); }
        public int GetCanonicalName(out Guid guid) { guid = Guid.Empty; return unchecked((int)0x80004001); }
        public int GetFlags(out uint flags) { flags = 0; return 0; }
        public int EnumSubCommands(out IntPtr e) { e = IntPtr.Zero; return unchecked((int)0x80004001); }

        // only for a single *_decrypt.cmd file
        public int GetState(IShellItemArray items, bool okToBeSlow, out uint state)
        {
            Util.Touch();
            state = 2;                                                  // ECS_HIDDEN
            try
            {
                List<string> p = Util.Paths(items);
                if (p.Count == 1 && p[0].EndsWith("_decrypt.cmd", StringComparison.OrdinalIgnoreCase)) state = 0;
            }
            catch { }
            return 0;
        }

        public int Invoke(IShellItemArray items, IntPtr bindCtx)
        {
            Util.Touch();
            try
            {
                List<string> p = Util.Paths(items);
                if (p.Count != 1) return 0;
                ProcessStartInfo psi = new ProcessStartInfo(p[0]);
                psi.UseShellExecute = true;
                psi.WorkingDirectory = Path.GetDirectoryName(p[0]);
                Process.Start(psi);
            }
            catch { }
            return 0;
        }
    }

    // opens the SecureEncrypt window (encrypt / decrypt tabs) without any item; last entry of the sub menu, after a separator
    [ComVisible(true), ClassInterface(ClassInterfaceType.None)]
    class OpenCommand : IExplorerCommand
    {
        public int GetTitle(IShellItemArray items, out string name) { Util.Touch(); name = Util.Label(2, "Open the SecureEncrypt window"); return 0; }
        public int GetIcon(IShellItemArray items, out string icon) { icon = Util.IconPath(); return 0; }
        public int GetToolTip(IShellItemArray items, out string tip) { tip = null; return unchecked((int)0x80004001); }
        public int GetCanonicalName(out Guid guid) { guid = Guid.Empty; return unchecked((int)0x80004001); }
        public int GetState(IShellItemArray items, bool okToBeSlow, out uint state) { Util.Touch(); state = 0; return 0; }
        public int GetFlags(out uint flags) { flags = 0x20; return 0; }       // ECF_SEPARATORBEFORE
        public int EnumSubCommands(out IntPtr e) { e = IntPtr.Zero; return unchecked((int)0x80004001); }

        public int Invoke(IShellItemArray items, IntPtr bindCtx)
        {
            Util.Touch();
            try
            {
                ProcessStartInfo psi = new ProcessStartInfo(Util.Target(), "/gui");
                psi.UseShellExecute = true;
                Process.Start(psi);
            }
            catch { }
            return 0;
        }
    }

    [ComVisible(true), ClassInterface(ClassInterfaceType.None)]
    class SubEnum : IEnumExplorerCommand
    {
        private IExplorerCommand[] list;
        private int pos;
        public SubEnum(IExplorerCommand[] l, int p) { list = l; pos = p; }

        public int Next(uint celt, IExplorerCommand[] commands, out uint fetched)
        {
            Util.Touch();
            uint n = 0;
            while (n < celt && pos < list.Length) { commands[n] = list[pos]; n++; pos++; }
            fetched = n;
            return n == celt ? 0 : 1;                                   // S_FALSE when fewer were left
        }
        public int Skip(uint celt) { pos += (int)celt; return pos <= list.Length ? 0 : 1; }
        public int Reset() { pos = 0; return 0; }
        public int Clone(out IEnumExplorerCommand clone) { clone = new SubEnum(list, pos); return 0; }
    }

    // the one entry in the new menu: "SecureEncrypt" with its own icon and the two commands as its sub menu.
    // It is hidden in the old menu ("Show more options"), where the normal registry entries (Encrypt / Decrypt) are shown instead.
    [ComVisible(true), ClassInterface(ClassInterfaceType.None)]
    class ParentCommand : IExplorerCommand, IObjectWithSite
    {
        private bool classic;
        public int SetSite(object site) { Util.Touch(); classic = SiteInfo.IsClassicMenu(site); return 0; }
        public int GetSite(ref Guid riid, out IntPtr site) { site = IntPtr.Zero; return unchecked((int)0x80004002); }
        public int GetTitle(IShellItemArray items, out string name) { Util.Touch(); name = "SecureEncrypt"; return 0; }
        public int GetIcon(IShellItemArray items, out string icon) { icon = Util.IconPath(); return 0; }
        public int GetToolTip(IShellItemArray items, out string tip) { tip = null; return unchecked((int)0x80004001); }
        public int GetCanonicalName(out Guid guid) { guid = Guid.Empty; return unchecked((int)0x80004001); }
        public int GetState(IShellItemArray items, bool okToBeSlow, out uint state) { Util.Touch(); state = classic ? 2u : 0u; return 0; }   // ECS_HIDDEN in the old menu
        public int Invoke(IShellItemArray items, IntPtr bindCtx) { return 0; }
        public int GetFlags(out uint flags) { flags = 1; return 0; }       // ECF_HASSUBCOMMANDS

        public int EnumSubCommands(out IntPtr enumCommands)
        {
            Util.Touch();
            SubEnum e = new SubEnum(new IExplorerCommand[] { new EncryptCommand(), new DecryptCommand(), new OpenCommand() }, 0);
            enumCommands = Marshal.GetComInterfaceForObject(e, typeof(IEnumExplorerCommand));
            return 0;
        }
    }

    class Factory : IClassFactory
    {
        private Type type;
        public Factory(Type t) { type = t; }

        public int CreateInstance(IntPtr outer, ref Guid riid, out IntPtr obj)
        {
            Util.Touch();
            obj = IntPtr.Zero;
            if (outer != IntPtr.Zero) return unchecked((int)0x80040110);          // CLASS_E_NOAGGREGATION
            object o = Activator.CreateInstance(type);
            IntPtr unk = Marshal.GetIUnknownForObject(o);
            try { return Marshal.QueryInterface(unk, ref riid, out obj); }
            finally { Marshal.Release(unk); }
        }

        public int LockServer(bool l) { Util.Touch(); return 0; }
    }

    static class Program
    {
        [DllImport("ole32.dll")]
        static extern int CoRegisterClassObject(ref Guid rclsid, [MarshalAs(UnmanagedType.Interface)] IClassFactory pUnk, uint context, uint flags, out uint cookie);
        [DllImport("ole32.dll")]
        static extern int CoRevokeClassObject(uint cookie);

        static readonly Guid ParentId = new Guid("5D3A7C61-2B4E-4F0A-9E1D-7A9B6C3E8F10");

        static int Main(string[] args)
        {
            bool embedding = false;
            for (int i = 0; i < args.Length; i++) if (args[i].IndexOf("Embedding", StringComparison.OrdinalIgnoreCase) >= 0) embedding = true;
            if (!embedding) return 0;                                              // started by hand: nothing to do

            uint c1;
            Guid g1 = ParentId;
            int h1 = CoRegisterClassObject(ref g1, new Factory(typeof(ParentCommand)), 4, 1, out c1);   // LOCAL_SERVER, MULTIPLEUSE
            if (h1 != 0) return 1;

            // stay a while after the last use: Explorer keeps the objects only for a moment
            Util.Touch();
            while ((DateTime.UtcNow - Util.Last).TotalSeconds < 30) Thread.Sleep(500);
            CoRevokeClassObject(c1);
            return 0;
        }
    }
}
