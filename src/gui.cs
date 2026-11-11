namespace SE.UI
{
    using System;
    using System.Collections.Generic;
    using System.Diagnostics;
    using System.Drawing;
    using System.Drawing.Drawing2D;
    using System.Drawing.Imaging;
    using System.Drawing.Text;
    using System.IO;
    using System.Runtime.InteropServices;
    using System.Security;
    using System.Text;
    using System.Threading;
    using System.Windows.Forms;

    // Window (GUI) mode. Everything that has to run on a worker thread is C#; PowerShell 2.0 cannot call back
    // into a script block from another thread. Texts come from the PowerShell language tables (Ui.S).
    // Look: dark "glass" window. Windows 11 acrylic, Windows 10 blur-behind, Windows 7 Aero glass; elsewhere a
    // plain dark background. All native calls are optional: if one fails the window simply stays opaque.
    public static class Ui
    {
        public static Dictionary<string, string> S = new Dictionary<string, string>();
        public static string[] CompressedExt = new string[0];
        public static volatile bool LastOk;
        internal static Exception Failure;

        // first character of a result line: warning colour / error colour (see GlassForm.FillSummary)
        public const string MarkWarn = "\u0001";
        public const string MarkBad = "\u0002";

        // PowerShell 2.0 cannot assign through the generic dictionary indexer
        public static void Put(string k, string v) { S[k] = v; }

        // language switch: a window sets LangRequest and closes; PowerShell loads the language and shows it again
        public static string LangRequest = "";
        public static string[] KeptItems = new string[0];
        internal static int KeptTab;
        internal static string KeptDecFile = "";
        internal static string[] LangCodes = new string[0];
        internal static string[] LangNames = new string[0];
        internal static string LangCurrent = "";

        public static void SetLanguages(string[] codes, string[] names, string current)
        {
            LangCodes = codes; LangNames = names; LangCurrent = current;
        }

        public static string T(string k)
        {
            string v;
            if (S.TryGetValue(k, out v)) return v;
            return k;
        }

        public static string TF(string k, object a0, object a1)
        {
            return string.Format(T(k), a0, a1);
        }

        internal static string FmtSize(double n)
        {
            if (n >= 1073741824.0) return string.Format("{0:N2} GB", n / 1073741824.0);
            if (n >= 1048576.0) return string.Format("{0:N2} MB", n / 1048576.0);
            return string.Format("{0:N2} KB", n / 1024.0);
        }

        public static string FmtDuration(double sec)
        {
            string h = T("unit_h"), m = T("unit_m"), s = T("unit_s");
            if (sec < 60.0) return string.Format("{0:F2} {1}", sec, s);
            long total = (long)Math.Round(sec);
            long hh = total / 3600, mm = (total % 3600) / 60, ss = total % 60;
            if (hh > 0) return string.Format("{0} {1} {2} {3} {4} {5}", hh, h, mm, m, ss, s);
            return string.Format("{0} {1} {2} {3}", mm, m, ss, s);
        }

        internal static bool Forbidden(string full)
        {
            string up = Environment.GetEnvironmentVariable("USERPROFILE");
            if (!string.IsNullOrEmpty(up))
            {
                up = up.TrimEnd('\\') + "\\";
                if (full.StartsWith(up, StringComparison.OrdinalIgnoreCase)) return false;
            }
            string root = Path.GetPathRoot(full).TrimEnd('\\');
            string sysDrive = Environment.GetEnvironmentVariable("SystemDrive");
            if (sysDrive != null && string.Equals(root, sysDrive, StringComparison.OrdinalIgnoreCase)) return true;
            if (full.IndexOf("$Recycle.Bin", StringComparison.OrdinalIgnoreCase) >= 0) return true;
            if (full.IndexOf("System Volume Information", StringComparison.OrdinalIgnoreCase) >= 0) return true;
            return false;
        }

        internal static SecureString ToSecure(string s)
        {
            SecureString r = new SecureString();
            for (int i = 0; i < s.Length; i++) r.AppendChar(s[i]);
            return r;
        }

        internal static string ErrorText(Exception ex)
        {
            if (ex is System.Reflection.TargetInvocationException && ex.InnerException != null) ex = ex.InnerException;
            if (ex is OperationCanceledException) return T("cancelled");
            if (ex is System.Security.Cryptography.CryptographicException) return T("mac_fail");
            if (ex.Message == "CHANGED") return T("changed");
            if (ex.Message == "EMPTY") return T("empty");
            if (ex.Message == "FORMAT") return T("format");
            return TF("err", ex.Message, null);
        }

        internal static string PickFile(IWin32Window owner, string title)
        {
            OpenFileDialog d = new OpenFileDialog();
            d.Title = title;
            d.CheckFileExists = true;
            d.Multiselect = false;
            if (d.ShowDialog(owner) == DialogResult.OK) return d.FileName;
            return null;
        }

        [DllImport("kernel32.dll")] private static extern IntPtr GetConsoleWindow();
        [DllImport("kernel32.dll")] private static extern uint GetConsoleProcessList(uint[] list, uint count);
        [DllImport("user32.dll")] private static extern bool ShowWindow(IntPtr h, int cmd);
        [DllImport("user32.dll")] private static extern bool SetProcessDPIAware();

        // Hides the console window only when it was opened just for this program (double click / right click).
        // From a terminal it stays: the process list then holds the shell as well.
        // brings it back (the window code failed after the console was hidden, the error text must be readable)
        public static void ShowOwnConsole()
        {
            try { IntPtr h = GetConsoleWindow(); if (h != IntPtr.Zero) ShowWindow(h, 5); } catch { }
        }

        internal static void HideOwnConsole()
        {
            try
            {
                IntPtr h = GetConsoleWindow();
                if (h == IntPtr.Zero) return;
                uint[] list = new uint[8];
                uint n = GetConsoleProcessList(list, 8);
                if (n > 0 && n <= 2) ShowWindow(h, 0);
            }
            catch { }
        }

        // Runs a form on its own STA thread (the PowerShell host thread is MTA, drag and drop needs STA).
        internal delegate Form FormMaker();

        // The form is created on that thread, after the process was made DPI aware: a form created earlier is laid out
        // at 96 dpi while its fonts already use the real dpi (text then overflows the controls on scaled displays).
        internal static int RunSta(FormMaker make)
        {
            LastOk = false;
            Failure = null;
            Thread t = new Thread(new ThreadStart(delegate
            {
                try
                {
                    try { SetProcessDPIAware(); } catch { }
                    AppIcon.SetAppId();
                    try { Application.EnableVisualStyles(); } catch { }
                    try { Application.SetCompatibleTextRenderingDefault(false); } catch { }
                    Theme.Init();
                    Application.Run(make());
                }
                catch (Exception ex) { Failure = ex; }
            }));
            t.SetApartmentState(ApartmentState.STA);
            t.Start();
            t.Join();
            if (Failure != null) throw Failure;
            return LastOk ? 0 : 1;
        }

        // head = the text part of the self extracting file (stub + decoder), built by PowerShell.
        public static int Encrypt(string[] items, string head)
        {
            // only system locations were given: report them once and do not open the window at all
            if (items != null && items.Length > 0)
            {
                List<string> bad = new List<string>();
                bool anyOk = false;
                for (int i = 0; i < items.Length; i++)
                {
                    string p = items[i];
                    if (string.IsNullOrEmpty(p)) continue;
                    string full;
                    try { full = Path.GetFullPath(p.Trim().Trim('"')); } catch { anyOk = true; continue; }
                    if (full.Length > 3) full = full.TrimEnd('\\');
                    if (Forbidden(full)) bad.Add(full); else anyOk = true;
                }
                if (!anyOk && bad.Count > 0)
                {
                    StringBuilder sb = new StringBuilder(T("forbidden"));
                    sb.Append("\r\n");
                    for (int i = 0; i < bad.Count && i < 12; i++) sb.Append("\r\n").Append(bad[i]);
                    if (bad.Count > 12) sb.Append("\r\n...");
                    MessageBox.Show(sb.ToString(), T("g_title_enc"), MessageBoxButtons.OK, MessageBoxIcon.Warning);
                    return 1;
                }
            }
            return RunSta(delegate { return new EncryptForm(items, head); });
        }

        public static int Decrypt(string selfPath, long dataStart)
        {
            return RunSta(delegate { return new DecryptForm(selfPath, dataStart); });
        }

        internal static volatile int SetupAction;

        // Install window. Returns 0 = close, 1 = install / update, 2 = uninstall; the caller does the work
        // (registry, files) in PowerShell and shows the window again with the result message.
        public static int Setup(bool installed, string message, bool messageOk)
        {
            SetupAction = 0;
            RunSta(delegate { return new SetupForm(installed, message, messageOk); });
            return SetupAction;
        }

        private static LinkLabel MakeLink(string text, string url, int x, int y, int w)
        {
            LinkLabel l = new LinkLabel();
            l.Text = text;
            l.SetBounds(x, y, w, 22);
            l.BackColor = Color.Transparent;
            l.LinkColor = Theme.AccentHi;
            l.ActiveLinkColor = Theme.Accent2;
            l.VisitedLinkColor = Theme.AccentHi;
            l.LinkBehavior = LinkBehavior.HoverUnderline;
            l.Font = Theme.Body;
            l.LinkClicked += new LinkLabelLinkClickedEventHandler(delegate { try { Process.Start(url); } catch { } });
            return l;
        }

        internal static void ShowAbout(IWin32Window owner)
        {
            Form d = new Form();
            d.Text = "SecureEncrypt v@@VERSION@@ - " + T("g_about");
            d.FormBorderStyle = FormBorderStyle.FixedDialog;
            d.StartPosition = FormStartPosition.CenterParent;
            d.MaximizeBox = false; d.MinimizeBox = false; d.ShowInTaskbar = false;
            d.Font = Theme.Body;
            d.ForeColor = Theme.Text;
            d.BackColor = Theme.Bg;
            d.KeyPreview = true;
            d.ClientSize = new Size(520, 262);
            Backdrop bg = new Backdrop();
            bg.SetBounds(0, 0, 520, 262);
            d.Controls.Add(bg);
            Card c = new Card();
            c.SetBounds(16, 16, 488, 178);
            bg.Controls.Add(c);

            Label l1 = new Label();
            l1.Text = T("g_about_by");
            l1.SetBounds(18, 16, 452, 22);
            l1.BackColor = Color.Transparent; l1.ForeColor = Theme.Text; l1.Font = Theme.Bold;
            c.Controls.Add(l1);
            // the sentence itself is the link, the address stays hidden
            LinkLabel coffee = MakeLink(T("g_about_coffee"), "https://buymeacoffee.com/abdullaherturk", 18, 52, 452);
            coffee.Font = Theme.Bold;
            c.Controls.Add(coffee);
            c.Controls.Add(MakeLink("github.com/abdullah-erturk", "https://github.com/abdullah-erturk", 18, 92, 452));
            c.Controls.Add(MakeLink("erturk-dev.netlify.app", "https://erturk-dev.netlify.app", 18, 118, 452));
            c.Controls.Add(MakeLink("erturk-dev.netlify.app/secureencrypt", "https://erturk-dev.netlify.app/secureencrypt", 18, 144, 452));

            FlatButton ok = new FlatButton(T("g_close"), true);
            ok.SetBounds(384, 208, 120, 38);
            ok.Click += new EventHandler(delegate { d.Close(); });
            bg.Controls.Add(ok);
            d.KeyDown += new KeyEventHandler(delegate(object s, KeyEventArgs e) { if (e.KeyCode == Keys.Escape) d.Close(); });
            d.Scale(new SizeF(Theme.F, Theme.F));
            d.HandleCreated += new EventHandler(delegate { AppIcon.Apply(d); });
            d.ShowDialog(owner);
            d.Dispose();
        }

        // Four-way answer for "already exists": 1 overwrite all, 2 rename, 3 skip all, 0 cancel.
        internal static int AskConflict(IWin32Window owner, string target)
        {
            Form d = new Form();
            d.Text = T("g_title_dec");
            d.FormBorderStyle = FormBorderStyle.FixedDialog;
            d.StartPosition = FormStartPosition.CenterParent;
            d.MaximizeBox = false; d.MinimizeBox = false; d.ShowInTaskbar = false;
            d.Font = Theme.Body;
            d.BackColor = Theme.Bg;
            d.ForeColor = Theme.Text;
            d.ClientSize = new Size(520, 150);
            Label l = new Label();
            l.Text = TF("g_conflict", target, null);
            l.SetBounds(16, 14, 488, 62);
            d.Controls.Add(l);
            string[] names = new string[] { T("g_c_over"), T("g_c_ren"), T("g_c_skip"), T("g_cancel") };
            int[] codes = new int[] { 1, 2, 3, 0 };
            int result = 0;
            for (int i = 0; i < 4; i++)
            {
                FlatButton b = new FlatButton(names[i], i == 0);
                b.SetBounds(16 + i * 124, 96, 118, 36);
                int code = codes[i];
                b.Click += new EventHandler(delegate { result = code; d.Close(); });
                d.Controls.Add(b);
            }
            d.Scale(new SizeF(Theme.F, Theme.F));
            d.HandleCreated += new EventHandler(delegate { AppIcon.Apply(d); });
            d.ShowDialog(owner);
            d.Dispose();
            return result;
        }
    }

    // ---------------------------------------------------------------- look

    internal static class Theme
    {
        public static Color Bg = Color.FromArgb(16, 18, 26);
        public static Color CardLine = Color.FromArgb(58, 255, 255, 255);
        public static Color Field = Color.FromArgb(18, 20, 29);
        public static Color FieldLine = Color.FromArgb(64, 70, 92);
        public static Color Text = Color.FromArgb(236, 239, 247);
        public static Color Dim = Color.FromArgb(146, 154, 174);
        public static Color Accent = Color.FromArgb(99, 102, 241);
        public static Color AccentHi = Color.FromArgb(129, 140, 248);
        public static Color Accent2 = Color.FromArgb(56, 189, 248);
        public static Color Danger = Color.FromArgb(248, 113, 113);
        public static Color Warn = Color.FromArgb(251, 191, 36);
        public static Color Ok = Color.FromArgb(74, 222, 128);

        // everything is drawn a little smaller than the system scale; F = device pixels per design unit
        public const float K = 0.9f;
        public static float F = K;

        // the tallest window (encrypt) is this many design units high; it has to fit the screen with its title bar
        public const int MaxDesignHeight = 704;
        public const int DesignWidth = 620;

        // device pixels per design unit: system dpi x K, but never more than what fits the working area
        public static float ComputeScale(float dpi, int workW, int workH, int chrome)
        {
            float s = dpi * K;
            float fitH = (workH - chrome) / (float)MaxDesignHeight;
            float fitW = (workW - 24) / (float)DesignWidth;
            if (fitH < s) s = fitH;
            if (fitW < s) s = fitW;
            if (s < 0.6f) s = 0.6f;
            return s;
        }

        public static void Init()
        {
            try
            {
                float dpi = 1f;
                using (Graphics g = Graphics.FromHwnd(IntPtr.Zero)) dpi = g.DpiX / 96f;
                Rectangle wa = Screen.PrimaryScreen.WorkingArea;
                int chrome = SystemInformation.CaptionHeight + SystemInformation.FrameBorderSize.Height * 2 + 20;
                F = ComputeScale(dpi, wa.Width, wa.Height, chrome);
                float kf = F / dpi;                      // fonts follow the same shrink
                Body = Make("Segoe UI", 9.5f * kf, FontStyle.Regular);
                Small = Make("Segoe UI", 9f * kf, FontStyle.Regular);
                Sub = Make("Segoe UI", 10.5f * kf, FontStyle.Regular);
                Bold = Make("Segoe UI Semibold", 9.5f * kf, FontStyle.Regular);
                Title = Make("Segoe UI Semibold", 16f * kf, FontStyle.Regular);
            }
            catch { F = K; }
        }

        public static int Px(int v) { return (int)Math.Round(v * F); }

        public static Font Body = Make("Segoe UI", 9.5f * K, FontStyle.Regular);
        public static Font Small = Make("Segoe UI", 9f * K, FontStyle.Regular);
        public static Font Sub = Make("Segoe UI", 10.5f * K, FontStyle.Regular);
        public static Font Bold = Make("Segoe UI Semibold", 9.5f * K, FontStyle.Regular);
        public static Font Title = Make("Segoe UI Semibold", 16f * K, FontStyle.Regular);

        private static Font Make(string name, float size, FontStyle st)
        {
            try { return new Font(name, size, st); }
            catch { return new Font(SystemFonts.DefaultFont.FontFamily, size, st); }
        }

        public static GraphicsPath Round(Rectangle r, int radius)
        {
            GraphicsPath p = new GraphicsPath();
            int d = radius * 2;
            if (d > r.Height) d = r.Height;
            if (d > r.Width) d = r.Width;
            if (d < 2) { p.AddRectangle(r); return p; }
            p.AddArc(r.X, r.Y, d, d, 180, 90);
            p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
            p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
            p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
            p.CloseFigure();
            return p;
        }
    }

    // The modern Explorer style folder dialog (IFileOpenDialog in folder mode, Windows Vista and later). WinForms'
    // FolderBrowserDialog is the old tree dialog; this one has the address bar, search and may pick several folders.
    internal static class FolderPicker
    {
        [ComImport, Guid("DC1C5A9C-E88A-4dde-A5A1-60F82A20AEF7")]
        private class FileOpenDialogClass { }

        [ComImport, Guid("43826d1e-e718-42ee-bc55-a1e261c37bfe"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        private interface IShellItem
        {
            void BindToHandler(IntPtr pbc, ref Guid bhid, ref Guid riid, out IntPtr ppv);
            void GetParent(out IShellItem ppsi);
            void GetDisplayName(uint sigdnName, out IntPtr ppszName);
            void GetAttributes(uint sfgaoMask, out uint psfgaoAttribs);
            void Compare(IShellItem psi, uint hint, out int piOrder);
        }

        [ComImport, Guid("b63ea76d-1f85-456f-a19c-48159efa858b"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        private interface IShellItemArray
        {
            void BindToHandler(IntPtr pbc, ref Guid bhid, ref Guid riid, out IntPtr ppvOut);
            void GetPropertyStore(int flags, ref Guid riid, out IntPtr ppv);
            void GetPropertyDescriptionList(IntPtr keyType, ref Guid riid, out IntPtr ppv);
            void GetAttributes(int attribFlags, uint sfgaoMask, out uint psfgaoAttribs);
            void GetCount(out uint pdwNumItems);
            void GetItemAt(uint dwIndex, out IShellItem ppsi);
            void EnumItems(out IntPtr ppenumShellItems);
        }

        // COM interfaces do not inherit in the managed declaration: the whole method list, in vtable order
        [ComImport, Guid("d57c7288-d4ad-4768-be02-9d969532d960"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        private interface IFileOpenDialog
        {
            [PreserveSig] int Show(IntPtr parent);
            void SetFileTypes(uint cFileTypes, IntPtr rgFilterSpec);
            void SetFileTypeIndex(uint iFileType);
            void GetFileTypeIndex(out uint piFileType);
            void Advise(IntPtr pfde, out uint pdwCookie);
            void Unadvise(uint dwCookie);
            void SetOptions(uint fos);
            void GetOptions(out uint pfos);
            void SetDefaultFolder(IShellItem psi);
            void SetFolder(IShellItem psi);
            void GetFolder(out IShellItem ppsi);
            void GetCurrentSelection(out IShellItem ppsi);
            void SetFileName([MarshalAs(UnmanagedType.LPWStr)] string pszName);
            void GetFileName([MarshalAs(UnmanagedType.LPWStr)] out string pszName);
            void SetTitle([MarshalAs(UnmanagedType.LPWStr)] string pszTitle);
            void SetOkButtonLabel([MarshalAs(UnmanagedType.LPWStr)] string pszText);
            void SetFileNameLabel([MarshalAs(UnmanagedType.LPWStr)] string pszLabel);
            void GetResult(out IShellItem ppsi);
            void AddPlace(IShellItem psi, int fdap);
            void SetDefaultExtension([MarshalAs(UnmanagedType.LPWStr)] string pszDefaultExtension);
            void Close(int hr);
            void SetClientGuid(ref Guid guid);
            void ClearClientData();
            void SetFilter(IntPtr pFilter);
            void GetResults(out IShellItemArray ppenum);
            void GetSelectedItems(out IShellItemArray ppsai);
        }

        // folders chosen by the user; an empty array when cancelled; null when this dialog is not available
        public static string[] Pick(IntPtr owner, string title)
        {
            try
            {
                IFileOpenDialog d = (IFileOpenDialog)new FileOpenDialogClass();
                uint opts;
                d.GetOptions(out opts);
                d.SetOptions(opts | 0x20 | 0x40 | 0x200 | 0x800);   // pick folders, file system only, several, path must exist
                if (!string.IsNullOrEmpty(title)) d.SetTitle(title);
                int hr = d.Show(owner);
                if (hr == unchecked((int)0x800704C7)) return new string[0];            // cancelled
                if (hr != 0) return null;
                IShellItemArray arr;
                d.GetResults(out arr);
                uint n;
                arr.GetCount(out n);
                List<string> res = new List<string>();
                for (uint i = 0; i < n; i++)
                {
                    IShellItem item;
                    arr.GetItemAt(i, out item);
                    IntPtr p;
                    item.GetDisplayName(0x80058000, out p);                           // SIGDN_FILESYSPATH
                    string s = Marshal.PtrToStringUni(p);
                    Marshal.FreeCoTaskMem(p);
                    if (!string.IsNullOrEmpty(s)) res.Add(s);
                }
                return res.ToArray();
            }
            catch { return null; }
        }
    }

    // The window icon (title bar, Alt+Tab, taskbar): the lock tile of the header, drawn at the sizes the system uses.
    internal static class AppIcon
    {
        [DllImport("user32.dll")] private static extern IntPtr SendMessage(IntPtr h, int msg, IntPtr w, IntPtr l);
        [DllImport("shell32.dll")] private static extern int SetCurrentProcessExplicitAppUserModelID([MarshalAs(UnmanagedType.LPWStr)] string appId);

        private static IntPtr small = IntPtr.Zero;
        private static IntPtr big = IntPtr.Zero;

        // own identity for the taskbar: its button is then not the one of the PowerShell that hosts this code
        public static void SetAppId()
        {
            try { SetCurrentProcessExplicitAppUserModelID("AbdullahErturk.SecureEncrypt"); } catch { }
        }

        private static Bitmap Draw(int px)
        {
            Bitmap bmp = new Bitmap(px, px, PixelFormat.Format32bppArgb);
            using (Graphics g = Graphics.FromImage(bmp))
            {
                g.SmoothingMode = SmoothingMode.AntiAlias;
                g.Clear(Color.Transparent);
                float s = px / 28f;
                g.ScaleTransform(s, s);
                Rectangle tile = new Rectangle(0, 0, 28, 28);
                using (GraphicsPath p = Theme.Round(tile, 8))
                using (LinearGradientBrush b = new LinearGradientBrush(tile, Theme.Accent, Theme.Accent2, 45f))
                    g.FillPath(b, p);
                using (Pen pen = new Pen(Color.White, 2f))
                {
                    g.DrawRectangle(pen, 9, 12, 10, 8);
                    g.DrawArc(pen, 10, 5, 8, 10, 180, 180);
                }
            }
            return bmp;
        }

        private static IntPtr Make(int px)
        {
            using (Bitmap bmp = Draw(px)) return bmp.GetHicon();
        }

        public static void Apply(Form f)
        {
            try
            {
                if (small == IntPtr.Zero) small = Make(Math.Max(16, SystemInformation.SmallIconSize.Width));
                if (big == IntPtr.Zero) big = Make(Math.Max(32, SystemInformation.IconSize.Width));
                f.Icon = Icon.FromHandle(big);                          // what WinForms itself puts on the window from now on
                SendMessage(f.Handle, 0x80, IntPtr.Zero, small);     // WM_SETICON, ICON_SMALL (title bar)
                SendMessage(f.Handle, 0x80, new IntPtr(1), big);      // ICON_BIG (Alt+Tab, taskbar)
            }
            catch { }
        }
    }

    // Title bar: dark, and on Windows 11 22H2+ the system acrylic. The body is frosted by Frost below.
    internal static class Glass
    {
        [DllImport("dwmapi.dll")] private static extern int DwmSetWindowAttribute(IntPtr h, int attr, ref int v, int size);

        public static void Apply(IntPtr h)
        {
            try
            {
                Version v = Environment.OSVersion.Version;
                if (v.Major < 10) return;
                int one = 1;
                DwmSetWindowAttribute(h, 20, ref one, 4);                   // dark title bar
                if (v.Build >= 22621)
                {
                    int acrylic = 3;                                         // DWMSBT_TRANSIENTWINDOW
                    DwmSetWindowAttribute(h, 38, ref acrylic, 4);
                }
            }
            catch { }
        }
    }

    // Software "frosted glass": the screen behind the window is captured, blurred and tinted, and used as the
    // background. Works the same on Windows 7 to 11, and the controls on top stay crisp and opaque.
    internal static class Frost
    {
        public static Bitmap Make(Rectangle r)
        {
            int w = r.Width, h = r.Height;
            Bitmap shot = new Bitmap(w, h, PixelFormat.Format32bppRgb);
            using (Graphics g = Graphics.FromImage(shot)) g.CopyFromScreen(r.Location, Point.Empty, r.Size);
            int sw = Math.Max(8, w / 12), sh = Math.Max(8, h / 12);
            Bitmap small = new Bitmap(sw, sh, PixelFormat.Format32bppRgb);
            using (Graphics g = Graphics.FromImage(small))
            {
                g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                g.DrawImage(shot, new Rectangle(0, 0, sw, sh), 0, 0, w, h, GraphicsUnit.Pixel);
            }
            shot.Dispose();
            Blur(small, 3, 3);
            Bitmap res = new Bitmap(w, h, PixelFormat.Format32bppRgb);
            using (Graphics g = Graphics.FromImage(res))
            using (ImageAttributes ia = new ImageAttributes())
            {
                ia.SetWrapMode(WrapMode.TileFlipXY);
                g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                g.DrawImage(small, new Rectangle(0, 0, w, h), 0, 0, sw, sh, GraphicsUnit.Pixel, ia);
                using (SolidBrush b = new SolidBrush(Color.FromArgb(165, 14, 16, 30))) g.FillRectangle(b, 0, 0, w, h);
                Backdrop.Glows(g, new Rectangle(0, 0, w, h));
            }
            small.Dispose();
            return res;
        }

        private static void Blur(Bitmap bmp, int radius, int passes)
        {
            int w = bmp.Width, h = bmp.Height;
            BitmapData d = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadWrite, PixelFormat.Format32bppRgb);
            try
            {
                int stride = d.Stride;
                byte[] a = new byte[stride * h];
                byte[] b = new byte[a.Length];
                Marshal.Copy(d.Scan0, a, 0, a.Length);
                for (int i = 0; i < passes; i++)
                {
                    Pass(a, b, w, h, stride, radius, true);
                    Pass(b, a, w, h, stride, radius, false);
                }
                Marshal.Copy(a, 0, d.Scan0, a.Length);
            }
            finally { bmp.UnlockBits(d); }
        }

        private static void Pass(byte[] src, byte[] dst, int w, int h, int stride, int r, bool horiz)
        {
            int len = horiz ? w : h;
            int lines = horiz ? h : w;
            int step = horiz ? 4 : stride;
            int lineStep = horiz ? stride : 4;
            int div = 2 * r + 1;
            for (int l = 0; l < lines; l++)
            {
                for (int c = 0; c < 3; c++)
                {
                    int bi = l * lineStep + c;
                    int sum = 0;
                    for (int i = -r; i <= r; i++) sum += src[bi + Math.Min(len - 1, Math.Max(0, i)) * step];
                    for (int i = 0; i < len; i++)
                    {
                        dst[bi + i * step] = (byte)(sum / div);
                        sum += src[bi + Math.Min(len - 1, i + r + 1) * step] - src[bi + Math.Max(0, i - r) * step];
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- controls

    internal class Card : Panel
    {
        public Card()
        {
            SetStyle(ControlStyles.SupportsTransparentBackColor | ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
            BackColor = Color.Transparent;
            ForeColor = Theme.Text;
            Font = Theme.Body;
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            Rectangle r = new Rectangle(0, 0, Width - 1, Height - 1);
            using (GraphicsPath p = Theme.Round(r, Theme.Px(14)))
            {
                // frosted glass: a dark tint plus a soft light that fades from the top edge
                using (SolidBrush b = new SolidBrush(Color.FromArgb(150, 14, 16, 26))) e.Graphics.FillPath(b, p);
                using (LinearGradientBrush b = new LinearGradientBrush(new Rectangle(0, 0, Math.Max(2, Width), Math.Max(2, Height)),
                    Color.FromArgb(40, 255, 255, 255), Color.FromArgb(6, 255, 255, 255), 90f))
                    e.Graphics.FillPath(b, p);
                using (Pen pen = new Pen(Theme.CardLine)) e.Graphics.DrawPath(pen, p);
            }
        }
    }

    // opaque page background: deep gradient with two soft colour glows, so the glass cards on top have something to show
    internal class Backdrop : Panel
    {
        public Backdrop()
        {
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
        }

        public static void Draw(Graphics g, Rectangle r)
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            using (LinearGradientBrush b = new LinearGradientBrush(new Rectangle(r.X, r.Y, Math.Max(2, r.Width), Math.Max(2, r.Height)),
                Color.FromArgb(26, 28, 58), Color.FromArgb(11, 13, 22), 65f))
                g.FillRectangle(b, r);
            Glows(g, r);
        }

        public static void Glows(Graphics g, Rectangle r)
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            Glow(g, new Point(r.Right - 30, r.Y + 30), 300, Color.FromArgb(80, 99, 102, 241));
            Glow(g, new Point(r.X + 30, r.Bottom - 20), 280, Color.FromArgb(60, 56, 189, 248));
        }

        private static void Glow(Graphics g, Point c, int radius, Color col)
        {
            using (GraphicsPath p = new GraphicsPath())
            {
                p.AddEllipse(c.X - radius, c.Y - radius, radius * 2, radius * 2);
                using (PathGradientBrush b = new PathGradientBrush(p))
                {
                    b.CenterColor = col;
                    b.SurroundColors = new Color[] { Color.FromArgb(0, col) };
                    g.FillPath(b, p);
                }
            }
        }

        protected override void OnPaintBackground(PaintEventArgs e)
        {
            GlassForm f = FindForm() as GlassForm;
            if (f != null && f.FrostImage != null)
                e.Graphics.DrawImage(f.FrostImage, ClientRectangle, new Rectangle(Left, Top, Width, Height), GraphicsUnit.Pixel);
            else
                Draw(e.Graphics, ClientRectangle);
        }
    }

    internal class Caption : Label
    {
        public Caption(string text, int x, int y, int w)
        {
            Text = text;
            SetBounds(x, y, w, 18);
            BackColor = Color.Transparent;
            ForeColor = Theme.Dim;
            Font = Theme.Small;
        }
    }

    internal class FlatButton : Control
    {
        private bool hot, down, primary;

        public FlatButton(string text, bool primary)
        {
            this.primary = primary;
            Text = text;
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.Selectable | ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
            Font = Theme.Bold;
            Cursor = Cursors.Hand;
            TabStop = true;
        }

        public void PerformClick() { if (Enabled && Visible) OnClick(EventArgs.Empty); }

        protected override void OnTextChanged(EventArgs e) { Invalidate(); base.OnTextChanged(e); }

        protected override void OnMouseEnter(EventArgs e) { hot = true; Invalidate(); base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { hot = false; down = false; Invalidate(); base.OnMouseLeave(e); }
        protected override void OnMouseDown(MouseEventArgs e) { down = true; Focus(); Invalidate(); base.OnMouseDown(e); }
        protected override void OnMouseUp(MouseEventArgs e)
        {
            bool fire = down && hot && e.Button == MouseButtons.Left;
            down = false; Invalidate();
            base.OnMouseUp(e);
            if (fire) OnClick(EventArgs.Empty);
        }
        protected override void OnKeyDown(KeyEventArgs e)
        {
            if (e.KeyCode == Keys.Space) { OnClick(EventArgs.Empty); e.Handled = true; }
            base.OnKeyDown(e);
        }
        protected override void OnEnabledChanged(EventArgs e) { Invalidate(); base.OnEnabledChanged(e); }
        protected override void OnGotFocus(EventArgs e) { Invalidate(); base.OnGotFocus(e); }
        protected override void OnLostFocus(EventArgs e) { Invalidate(); base.OnLostFocus(e); }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
            Rectangle r = new Rectangle(0, 0, Width - 1, Height - 1);
            Color fill, line, fore;
            if (!Enabled) { fill = Color.FromArgb(40, 44, 58); line = fill; fore = Color.FromArgb(100, 106, 124); }
            else if (primary)
            {
                fill = down ? Theme.Accent : (hot ? Theme.AccentHi : Theme.Accent);
                line = Theme.AccentHi; fore = Color.White;
            }
            else
            {
                fill = down ? Color.FromArgb(52, 57, 76) : (hot ? Color.FromArgb(44, 49, 67) : Color.FromArgb(34, 38, 53));
                line = Theme.CardLine; fore = Theme.Text;
            }
            using (GraphicsPath p = Theme.Round(r, Theme.Px(9)))
            {
                using (SolidBrush b = new SolidBrush(fill)) g.FillPath(b, p);
                using (Pen pen = new Pen(Focused ? Theme.Accent2 : line)) g.DrawPath(pen, p);
            }
            TextRenderer.DrawText(g, Text, Font, new Rectangle(0, 0, Width, Height), fore,
                TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine | TextFormatFlags.EndEllipsis);
        }
    }

    // a text box inside a rounded frame
    internal class Field : Control
    {
        public TextBox Box;
        private bool focus;

        public Field(bool password)
        {
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
            Box = new TextBox();
            Box.BorderStyle = BorderStyle.None;
            Box.BackColor = Theme.Field;
            Box.ForeColor = Theme.Text;
            Box.Font = Theme.Body;
            Box.UseSystemPasswordChar = password;
            Box.GotFocus += new EventHandler(delegate { focus = true; Invalidate(); });
            Box.LostFocus += new EventHandler(delegate { focus = false; Invalidate(); });
            Controls.Add(Box);
        }

        public override string Text { get { return Box.Text; } set { Box.Text = value; } }

        protected override void OnLayout(LayoutEventArgs e)
        {
            int h = Box.PreferredHeight;
            Box.SetBounds(Theme.Px(12), (Height - h) / 2, Math.Max(10, Width - Theme.Px(24)), h);
            base.OnLayout(e);
        }

        protected override void OnEnabledChanged(EventArgs e) { Box.Enabled = Enabled; Invalidate(); base.OnEnabledChanged(e); }

        protected override void OnPaint(PaintEventArgs e)
        {
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            Rectangle r = new Rectangle(0, 0, Width - 1, Height - 1);
            using (GraphicsPath p = Theme.Round(r, Theme.Px(8)))
            {
                using (SolidBrush b = new SolidBrush(Enabled ? Theme.Field : Color.FromArgb(28, 31, 42))) e.Graphics.FillPath(b, p);
                using (Pen pen = new Pen(focus ? Theme.AccentHi : Theme.FieldLine, focus ? 1.6f : 1f)) e.Graphics.DrawPath(pen, p);
            }
        }
    }

    // pill shaped choice of one out of a few
    internal class Segmented : Control
    {
        private string[] opts;
        private int sel;

        public Segmented(string[] options)
        {
            opts = options;
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.SupportsTransparentBackColor | ControlStyles.Selectable, true);
            BackColor = Color.Transparent;
            Font = Theme.Body;
            Cursor = Cursors.Hand;
            TabStop = true;
        }

        public int SelectedIndex { get { return sel; } set { sel = value; Invalidate(); } }

        // raised when the USER picked another segment (not when SelectedIndex is set from code)
        public event EventHandler Changed;

        private void Pick(int i)
        {
            if (i == sel) return;
            sel = i;
            Invalidate();
            if (Changed != null) Changed(this, EventArgs.Empty);
        }

        protected override void OnMouseDown(MouseEventArgs e)
        {
            if (!Enabled) return;
            int i = e.X * opts.Length / Math.Max(1, Width);
            Focus();
            if (i >= 0 && i < opts.Length) Pick(i);
            base.OnMouseDown(e);
        }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            if (e.KeyCode == Keys.Right && sel < opts.Length - 1) { Pick(sel + 1); e.Handled = true; }
            if (e.KeyCode == Keys.Left && sel > 0) { Pick(sel - 1); e.Handled = true; }
            base.OnKeyDown(e);
        }

        protected override bool IsInputKey(Keys k) { return k == Keys.Left || k == Keys.Right || base.IsInputKey(k); }
        protected override void OnEnabledChanged(EventArgs e) { Invalidate(); base.OnEnabledChanged(e); }
        protected override void OnGotFocus(EventArgs e) { Invalidate(); base.OnGotFocus(e); }
        protected override void OnLostFocus(EventArgs e) { Invalidate(); base.OnLostFocus(e); }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            Rectangle r = new Rectangle(0, 0, Width - 1, Height - 1);
            using (GraphicsPath p = Theme.Round(r, r.Height / 2))
            {
                using (SolidBrush b = new SolidBrush(Theme.Field)) g.FillPath(b, p);
                using (Pen pen = new Pen(Focused ? Theme.Accent2 : Theme.FieldLine)) g.DrawPath(pen, p);
            }
            int w = Width / opts.Length;
            for (int i = 0; i < opts.Length; i++)
            {
                Rectangle cell = new Rectangle(i * w + Theme.Px(3), Theme.Px(3), w - Theme.Px(6), Height - Theme.Px(7));
                if (i == sel)
                {
                    using (GraphicsPath p = Theme.Round(cell, cell.Height / 2))
                    using (LinearGradientBrush b = new LinearGradientBrush(cell, Theme.Accent, Theme.AccentHi, 0f))
                        g.FillPath(b, p);
                }
                Color fore = !Enabled ? Color.FromArgb(100, 106, 124) : (i == sel ? Color.White : Theme.Dim);
                TextRenderer.DrawText(g, opts[i], Font, cell, fore,
                    TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine | TextFormatFlags.EndEllipsis);
            }
        }
    }

    internal class GlowBar : Control
    {
        private int val;

        public GlowBar()
        {
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
        }

        public int Value { get { return val; } set { val = Math.Max(0, Math.Min(100, value)); Invalidate(); } }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            Rectangle r = new Rectangle(0, 0, Width - 1, Height - 1);
            using (GraphicsPath p = Theme.Round(r, r.Height / 2))
                using (SolidBrush b = new SolidBrush(Theme.Field)) g.FillPath(b, p);
            int w = (int)((Width - 1) * (long)val / 100);
            if (w < r.Height) w = val > 0 ? r.Height : 0;
            if (w > 0)
            {
                Rectangle f = new Rectangle(0, 0, w, r.Height);
                using (GraphicsPath p = Theme.Round(f, f.Height / 2))
                using (LinearGradientBrush b = new LinearGradientBrush(new Rectangle(0, 0, Math.Max(2, Width), Height), Theme.Accent, Theme.Accent2, 0f))
                    g.FillPath(b, p);
            }
        }
    }

    internal class ItemList : ListBox
    {
        public ItemList()
        {
            DrawMode = DrawMode.OwnerDrawFixed;
            ItemHeight = Theme.Px(36);
            BorderStyle = BorderStyle.None;
            BackColor = Theme.Field;
            ForeColor = Theme.Text;
            Font = Theme.Body;
            IntegralHeight = false;
            SelectionMode = SelectionMode.MultiExtended;
        }

        protected override void OnDrawItem(DrawItemEventArgs e)
        {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            bool sel = (e.State & DrawItemState.Selected) != 0;
            using (SolidBrush b = new SolidBrush(sel ? Color.FromArgb(70, 99, 102, 241) : Theme.Field)) g.FillRectangle(b, e.Bounds);
            if (e.Index < 0) return;
            string full = (string)Items[e.Index];
            string name = Path.GetFileName(full.TrimEnd('\\'));
            if (string.IsNullOrEmpty(name)) name = full;
            string dir = Path.GetDirectoryName(full.TrimEnd('\\'));
            if (dir == null) dir = "";
            bool isDir = Directory.Exists(full);
            Rectangle ic = new Rectangle(e.Bounds.X + Theme.Px(8), e.Bounds.Y + Theme.Px(9), Theme.Px(18), Theme.Px(18));
            using (GraphicsPath p = Theme.Round(ic, Theme.Px(4)))
            using (SolidBrush b = new SolidBrush(isDir ? Theme.Warn : Theme.Accent2)) g.FillPath(b, p);
            TextRenderer.DrawText(g, name, Theme.Bold, new Rectangle(e.Bounds.X + Theme.Px(34), e.Bounds.Y + Theme.Px(2), e.Bounds.Width - Theme.Px(40), Theme.Px(18)), Theme.Text,
                TextFormatFlags.Left | TextFormatFlags.SingleLine | TextFormatFlags.EndEllipsis | TextFormatFlags.NoPrefix);
            TextRenderer.DrawText(g, dir, Theme.Small, new Rectangle(e.Bounds.X + Theme.Px(34), e.Bounds.Y + Theme.Px(18), e.Bounds.Width - Theme.Px(40), Theme.Px(16)), Theme.Dim,
                TextFormatFlags.Left | TextFormatFlags.SingleLine | TextFormatFlags.PathEllipsis | TextFormatFlags.NoPrefix);
        }
    }

    internal class DarkColors : ProfessionalColorTable
    {
        private static Color Back = Color.FromArgb(30, 33, 46);
        public override Color ToolStripDropDownBackground { get { return Back; } }
        public override Color ImageMarginGradientBegin { get { return Back; } }
        public override Color ImageMarginGradientMiddle { get { return Back; } }
        public override Color ImageMarginGradientEnd { get { return Back; } }
        public override Color MenuBorder { get { return Color.FromArgb(70, 76, 98); } }
        public override Color MenuItemBorder { get { return Theme.AccentHi; } }
        public override Color MenuItemSelected { get { return Color.FromArgb(62, 68, 104); } }
        public override Color MenuItemSelectedGradientBegin { get { return Color.FromArgb(62, 68, 104); } }
        public override Color MenuItemSelectedGradientEnd { get { return Color.FromArgb(62, 68, 104); } }
        public override Color CheckBackground { get { return Theme.Accent; } }
        public override Color CheckSelectedBackground { get { return Theme.Accent; } }
        public override Color CheckPressedBackground { get { return Theme.Accent; } }
    }

    // ---------------------------------------------------------------- window base

    internal abstract class GlassForm : Form
    {
        private Bitmap frost;
        private Point lastFrostPos;
        private float dpiScale = 1f;
        protected string subtitle = "";
        protected Panel pageOpts, pageWork;
        protected Panel pageAlt;                // optional second options page (the decrypt tab)
        protected Control tabBar;               // disabled while the work page is shown
        protected GlowBar bar;
        protected Label status;
        protected RichTextBox summary;
        protected FlatButton btnOpen, btnStop, btnLang;
        internal bool busy;
        protected string openTarget;
        protected const int HeaderH = 70;

        protected GlassForm(string title, string subtitle, int clientH) : this(title, subtitle, 620, clientH) { }

        // clientW / clientH are in design units (96 dpi); the cards use clientW - 40, the fields inside them clientW - 76
        protected GlassForm(string title, string subtitle, int clientW, int clientH)
        {
            Text = title;
            this.subtitle = subtitle;
            Font = Theme.Body;
            ForeColor = Theme.Text;
            BackColor = Theme.Bg;
            FormBorderStyle = FormBorderStyle.FixedSingle;
            MaximizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            AutoScaleMode = AutoScaleMode.None;       // scaled once, by hand, in OnLoad (WinForms' own scaling runs too early here)
            ClientSize = new Size(clientW, clientH);
            DoubleBuffered = true;
            KeyPreview = true;
            Opacity = 0;                    // shown after the frosted background is ready (OnShown)

            pageOpts = new Backdrop();
            pageOpts.SetBounds(0, HeaderH, clientW, clientH - HeaderH);
            pageWork = new Backdrop();
            pageWork.SetBounds(0, HeaderH, clientW, clientH - HeaderH);
            pageWork.Visible = false;
            FlatButton about = new FlatButton(Ui.T("g_about"), false);
            about.SetBounds(clientW - 20 - 110, 20, 110, 30);
            about.TabStop = false;
            about.Click += new EventHandler(delegate { Ui.ShowAbout(this); });
            Controls.Add(about);
            if (Ui.LangCodes.Length > 1)
            {
                string cur = Ui.LangCurrent;
                for (int i = 0; i < Ui.LangCodes.Length; i++) if (Ui.LangCodes[i] == Ui.LangCurrent) cur = Ui.LangNames[i];
                btnLang = new FlatButton(cur + " ▾", false);
                btnLang.SetBounds(clientW - 20 - 110 - 8 - 130, 20, 130, 30);
                btnLang.TabStop = false;
                btnLang.Click += new EventHandler(OnLangClick);
                Controls.Add(btnLang);
            }
            Controls.Add(pageOpts);
            Controls.Add(pageWork);

            Card c = new Card();
            int ph = clientH - HeaderH;
            c.SetBounds(20, 0, clientW - 40, ph - 62);
            pageWork.Controls.Add(c);
            status = new Label();
            status.SetBounds(18, 16, clientW - 76, 22);
            status.BackColor = Color.Transparent; status.ForeColor = Theme.Text; status.Font = Theme.Bold;
            bar = new GlowBar();
            bar.SetBounds(18, 46, clientW - 76, 10);
            summary = new RichTextBox();
            summary.ReadOnly = true; summary.ScrollBars = RichTextBoxScrollBars.Vertical; summary.DetectUrls = false;
            summary.BorderStyle = BorderStyle.None;
            summary.BackColor = Theme.Field; summary.ForeColor = Theme.Text; summary.Font = Theme.Small;
            summary.SetBounds(18, 72, clientW - 76, ph - 62 - 90);
            summary.Visible = false;
            c.Controls.Add(status); c.Controls.Add(bar); c.Controls.Add(summary);
            btnOpen = new FlatButton(Ui.T("g_openfolder"), false);
            btnOpen.SetBounds(20, ph - 48, 170, 38);
            btnOpen.Visible = false;
            btnStop = new FlatButton(Ui.T("g_cancel"), false);
            btnStop.SetBounds(clientW - 20 - 140, ph - 48, 140, 38);
            pageWork.Controls.Add(btnOpen); pageWork.Controls.Add(btnStop);
            btnOpen.Click += new EventHandler(OnOpenFolder);
            btnStop.Click += new EventHandler(OnStopClick);
            FormClosing += new FormClosingEventHandler(HandleClosing);
        }

        // All sizes are written in design units. Theme.F (system dpi x the compact factor) turns them into pixels.
        protected override void OnLoad(EventArgs e)
        {
            Scale(new SizeF(Theme.F, Theme.F));
            CenterToScreen();
            base.OnLoad(e);
        }

        protected override void OnHandleCreated(EventArgs e)
        {
            base.OnHandleCreated(e);
            Glass.Apply(Handle);
            AppIcon.Apply(this);
            dpiScale = Theme.F;
        }

        internal Bitmap FrostImage { get { return frost; } }

        // captures and blurs the screen behind the window; the window is made see-through for a moment
        protected void RefreshFrost()
        {
            try
            {
                Rectangle r = RectangleToScreen(ClientRectangle);
                // the window has to be gone while the screen behind it is captured; it fades out and in quickly
                // instead of blinking (the first call, from OnShown, starts from Opacity 0 and only fades in)
                if (Opacity > 0.5)
                {
                    double[] down = new double[] { 0.7, 0.4, 0.15 };
                    for (int i = 0; i < down.Length; i++) { Opacity = down[i]; Application.DoEvents(); Thread.Sleep(12); }
                }
                Opacity = 0;
                Application.DoEvents();
                Thread.Sleep(110);
                Application.DoEvents();
                Bitmap nb = Frost.Make(r);
                if (frost != null) frost.Dispose();
                frost = nb;
                Invalidate(true);
                Update();
                double[] up = new double[] { 0.25, 0.5, 0.75, 0.9, 1.0 };
                for (int i = 0; i < up.Length; i++) { Opacity = up[i]; Application.DoEvents(); Thread.Sleep(14); }
                lastFrostPos = Location;
            }
            catch { try { Opacity = 1; } catch { } }
        }

        protected override void OnShown(EventArgs e)
        {
            base.OnShown(e);
            RefreshFrost();
            AppIcon.Apply(this);            // once more: the system sets its own icon while the window is being shown
            Ui.HideOwnConsole();            // only now that the window is up: an earlier failure stays visible in the console
            // started from a console window or a helper, Windows may open it behind other windows
            try { TopMost = true; TopMost = false; Activate(); } catch { }
        }

        // after the window was moved the picture behind it is another one
        protected override void WndProc(ref Message m)
        {
            base.WndProc(ref m);
            // WM_EXITSIZEMOVE; a click on the title bar without moving the window needs no new picture
            if (m.Msg == 0x0232 && !busy && Location != lastFrostPos) RefreshFrost();
        }

        protected override void OnPaintBackground(PaintEventArgs e)
        {
            if (frost != null) e.Graphics.DrawImage(frost, 0, 0, frost.Width, frost.Height);
            else Backdrop.Draw(e.Graphics, new Rectangle(0, 0, ClientSize.Width, ClientSize.Height));
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
            g.ScaleTransform(dpiScale, dpiScale);        // the header is drawn in 96 dpi units, the controls are scaled by Windows
            // accent dot + title
            Rectangle dot = new Rectangle(24, 22, 28, 28);
            using (GraphicsPath p = Theme.Round(dot, 8))
            using (LinearGradientBrush b = new LinearGradientBrush(dot, Theme.Accent, Theme.Accent2, 45f))
                g.FillPath(b, p);
            using (Pen pen = new Pen(Color.White, 2f))
            {
                g.DrawRectangle(pen, 33, 34, 10, 8);
                g.DrawArc(pen, 34, 27, 8, 10, 180, 180);
            }
            // the fonts already carry the scale: the text is drawn without the transform, only its position is scaled
            g.ResetTransform();
            using (SolidBrush b = new SolidBrush(Theme.Text)) g.DrawString("SecureEncrypt", Theme.Title, b, 62 * dpiScale, 12 * dpiScale);
            // the subtitle must stay left of the tab bar (or of the language button): shrink it a little, then cut it with "..."
            float subX = 64 * dpiScale;
            float subRight = (tabBar != null) ? tabBar.Left : (btnLang != null ? btnLang.Left : ClientSize.Width);
            float subAvail = subRight - 12 * dpiScale - subX;
            Font subFont = Theme.Sub; Font subTmp = null;
            if (subAvail > 20 * dpiScale)
            {
                float subW = g.MeasureString(subtitle, subFont).Width;
                if (subW > subAvail)
                {
                    float ratio = subAvail / subW;
                    if (ratio < 0.82f) ratio = 0.82f;
                    subTmp = new Font(subFont.FontFamily, subFont.Size * ratio, subFont.Style, subFont.Unit);
                    subFont = subTmp;
                }
            }
            else subAvail = ClientSize.Width - subX;
            using (StringFormat sf = new StringFormat())
            using (SolidBrush b = new SolidBrush(Color.FromArgb(214, 220, 234)))
            {
                sf.Trimming = StringTrimming.EllipsisCharacter;
                sf.FormatFlags = StringFormatFlags.NoWrap;
                g.DrawString(subtitle, subFont, b, new RectangleF(subX, 43 * dpiScale, subAvail, subFont.Height + 4 * dpiScale), sf);
            }
            if (subTmp != null) subTmp.Dispose();
        }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            if (e.KeyCode == Keys.Escape && !busy) { Close(); e.Handled = true; }
            base.OnKeyDown(e);
        }

        // what has to survive a language switch (the window is shown again)
        protected virtual void KeepState() { }

        private void OnLangClick(object s, EventArgs e)
        {
            if (busy) return;
            ContextMenuStrip m = new ContextMenuStrip();
            m.Renderer = new ToolStripProfessionalRenderer(new DarkColors());
            m.BackColor = Color.FromArgb(30, 33, 46);
            m.ForeColor = Theme.Text;
            m.Font = Theme.Body;
            for (int i = 0; i < Ui.LangCodes.Length; i++)
            {
                ToolStripMenuItem it = new ToolStripMenuItem(Ui.LangNames[i]);
                it.ForeColor = Theme.Text;
                string code = Ui.LangCodes[i];
                it.Checked = code == Ui.LangCurrent;
                it.Click += new EventHandler(delegate
                {
                    if (code == Ui.LangCurrent || busy) return;
                    KeepState();
                    Ui.LangRequest = code;
                    Close();
                });
                m.Items.Add(it);
            }
            m.Show(btnLang, new Point(0, btnLang.Height + 2));
        }

        internal void ShowWork()
        {
            if (btnLang != null) btnLang.Enabled = false;
            if (tabBar != null) tabBar.Enabled = false;
            pageOpts.Visible = false;
            if (pageAlt != null) pageAlt.Visible = false;
            pageWork.Visible = true;
            summary.Visible = false;
            btnOpen.Visible = false;
            btnStop.Text = Ui.T("g_cancel");
            btnStop.Enabled = true;
            bar.Value = 0;
            status.ForeColor = Theme.Text;
            status.Text = Ui.T("g_working");
        }

        internal void HookSinks()
        {
            SE.ProgressBar.CancelRequested = false;
            Core.ConflictMode = 0;
            SE.ProgressBar.Sink = new ProgressHandler(delegate(string label, int pct)
            {
                try { BeginInvoke(new MethodInvoker(delegate { bar.Value = pct; status.Text = label.Trim() + "  " + pct + "%"; })); } catch { }
            });
            Core.StatusSink = new StatusHandler(delegate(string text)
            {
                try { BeginInvoke(new MethodInvoker(delegate { status.Text = text; })); } catch { }
            });
        }

        internal void UnhookSinks()
        {
            SE.ProgressBar.Sink = null;
            Core.StatusSink = null;
            Core.ConflictSink = null;
        }

        // fills the result box line by line: a line that starts with Ui.MarkWarn is shown in the warning colour, one that
        // starts with Ui.MarkBad in the error colour (the marker itself is not shown); the rest in the normal text colour
        private void FillSummary(string text)
        {
            summary.Clear();
            string[] lines = text.Replace("\r\n", "\n").TrimEnd('\n').Split('\n');
            for (int i = 0; i < lines.Length; i++)
            {
                string line = lines[i];
                Color col = Theme.Text;
                if (line.StartsWith(Ui.MarkWarn)) { col = Theme.Warn; line = line.Substring(1); }
                else if (line.StartsWith(Ui.MarkBad)) { col = Theme.Danger; line = line.Substring(1); }
                summary.SelectionStart = summary.TextLength;
                summary.SelectionLength = 0;
                summary.SelectionColor = col;
                summary.AppendText(i < lines.Length - 1 ? line + "\n" : line);
            }
            summary.SelectionStart = 0;
            summary.SelectionLength = 0;
            summary.ScrollToCaret();
        }

        // called on the UI thread when the worker has finished
        internal void ShowResult(bool ok, string statusText, string summaryText, string target)
        {
            busy = false;
            openTarget = target;
            bar.Value = ok ? 100 : bar.Value;
            status.ForeColor = ok ? Theme.Ok : Theme.Danger;
            status.Text = statusText;
            if (summaryText != null && summaryText.Length > 0) { FillSummary(summaryText); summary.Visible = true; }
            btnOpen.Visible = target != null;
            btnStop.Text = Ui.T("g_close");
            btnStop.Enabled = true;
            if (ok) Ui.LastOk = true;
        }

        protected virtual void OnOpenFolder(object s, EventArgs e)
        {
            try
            {
                if (openTarget == null) return;
                if (File.Exists(openTarget)) Process.Start("explorer.exe", "/select,\"" + openTarget + "\"");
                else Process.Start("explorer.exe", "\"" + openTarget + "\"");
            }
            catch { }
        }

        private void OnStopClick(object s, EventArgs e)
        {
            if (busy) { SE.ProgressBar.CancelRequested = true; btnStop.Enabled = false; return; }
            Close();
        }

        protected virtual void HandleClosing(object s, FormClosingEventArgs e)
        {
            if (busy) { SE.ProgressBar.CancelRequested = true; e.Cancel = true; }
        }

        internal Label MakeLabel(Control parent, string text, int x, int y, int w, Font f, Color c)
        {
            Label l = new Label();
            l.Text = text;
            l.SetBounds(x, y, w, 20);
            l.BackColor = Color.Transparent; l.ForeColor = c; l.Font = f;
            parent.Controls.Add(l);
            return l;
        }

        internal void Warn(string text)
        {
            MessageBox.Show(this, text, Text, MessageBoxButtons.OK, MessageBoxIcon.Warning);
        }

        internal bool Confirm(string text)
        {
            return MessageBox.Show(this, text, Text, MessageBoxButtons.YesNo, MessageBoxIcon.Question) == DialogResult.Yes;
        }
    }

    // ---------------------------------------------------------------- encrypt window

    internal class EncryptForm : GlassForm
    {
        private string head;
        private ItemList list;
        private Field pw1, pw2, kf;
        private Label strength;
        private Segmented del;
        private FlatButton btnAddF, btnAddD, btnRem, btnKf, btnGo, btnCancel;
        private Segmented tabs;
        private DecryptPanel dec;

        public EncryptForm(string[] items, string head) : base(Ui.T("g_title_enc"), Ui.T("g_sub_enc"), 900, 540)
        {
            this.head = head;
            AllowDrop = true;

            // two columns like the browser page: the items on the left, the password / key file on the right
            Card a = new Card(); a.SetBounds(20, 0, 420, 268); pageOpts.Controls.Add(a);
            a.Controls.Add(new Caption(Ui.T("g_items"), 18, 12, 384));
            list = new ItemList(); list.SetBounds(18, 36, 384, 170); list.AllowDrop = true;
            a.Controls.Add(list);
            btnAddF = new FlatButton(Ui.T("g_add_files"), false); btnAddF.SetBounds(18, 214, 120, 36);
            btnAddD = new FlatButton(Ui.T("g_add_folder"), false); btnAddD.SetBounds(150, 214, 120, 36);
            btnRem = new FlatButton(Ui.T("g_remove"), false); btnRem.SetBounds(282, 214, 120, 36);
            a.Controls.Add(btnAddF); a.Controls.Add(btnAddD); a.Controls.Add(btnRem);

            Card b = new Card(); b.SetBounds(452, 0, 428, 268); pageOpts.Controls.Add(b);
            b.Controls.Add(new Caption(Ui.T("g_pw"), 18, 12, 230));
            strength = MakeLabel(b, "", 250, 12, 160, Theme.Small, Theme.Dim);
            strength.TextAlign = ContentAlignment.TopRight;
            pw1 = new Field(true); pw1.SetBounds(18, 34, 392, 36); b.Controls.Add(pw1);
            b.Controls.Add(new Caption(Ui.T("g_pw2"), 18, 78, 392));
            pw2 = new Field(true); pw2.SetBounds(18, 100, 392, 36); b.Controls.Add(pw2);
            b.Controls.Add(new Caption(Ui.T("g_kf"), 18, 144, 392));
            kf = new Field(false); kf.SetBounds(18, 166, 280, 36); b.Controls.Add(kf);
            btnKf = new FlatButton(Ui.T("g_browse"), false); btnKf.SetBounds(306, 166, 104, 36); b.Controls.Add(btnKf);
            // why the password is optional: without one the data is only obfuscated, not encrypted
            Label pwHint = MakeLabel(b, Ui.T("g_pw_hint"), 18, 208, 392, Theme.Small, Theme.Dim);
            pwHint.Height = 54;

            Card c = new Card(); c.SetBounds(20, 280, 860, 78); pageOpts.Controls.Add(c);
            c.Controls.Add(new Caption(Ui.T("g_del"), 18, 10, 824));
            del = new Segmented(new string[] { Ui.T("g_del0"), Ui.T("g_del1"), Ui.T("g_del2") });
            del.SetBounds(18, 32, 824, 34); c.Controls.Add(del);

            Label note = MakeLabel(pageOpts, Ui.T("dont_forget"), 24, 364, 852, Theme.Small, Theme.Warn);
            note.Height = 40;                        // two lines of the small font plus a margin (longer translations wrap too)

            btnCancel = new FlatButton(Ui.T("g_cancel"), false); btnCancel.SetBounds(630, 410, 110, 38);
            btnGo = new FlatButton(Ui.T("g_encrypt"), true); btnGo.SetBounds(750, 410, 130, 38);
            pageOpts.Controls.Add(btnCancel); pageOpts.Controls.Add(btnGo);

            // the "Decrypt" tab: same window, second page (a *_decrypt.cmd is chosen or dropped there)
            pageAlt = new Backdrop();
            pageAlt.SetBounds(0, HeaderH, 900, 540 - HeaderH);
            pageAlt.Visible = false;
            Controls.Add(pageAlt);
            dec = new DecryptPanel(this, pageAlt, true, null, 0);
            tabs = new Segmented(new string[] { Ui.T("g_encrypt"), Ui.T("g_decrypt") });
            tabs.SetBounds(360, 18, 250, 34);
            tabBar = tabs;
            Controls.Add(tabs);
            tabs.Changed += new EventHandler(delegate { ShowTab(tabs.SelectedIndex); });

            // one *_decrypt.cmd dropped on SecureEncrypt.cmd (or sent to it): decrypt it, do not encrypt it again
            if (items != null && items.Length == 1 && Ui.KeptTab == 0 && Ui.KeptDecFile.Length == 0 && items[0] != null
                && items[0].Trim().Trim('"').EndsWith("_decrypt.cmd", StringComparison.OrdinalIgnoreCase)
                && File.Exists(items[0].Trim().Trim('"')))
            {
                Ui.KeptDecFile = items[0].Trim().Trim('"');
                Ui.KeptTab = 1;
                items = null;
            }
            if (items != null) for (int i = 0; i < items.Length; i++) AddItem(items[i]);
            ShowRefused();
            // after a language switch the same tab and file are shown again
            if (Ui.KeptDecFile.Length > 0) dec.SetFile(Ui.KeptDecFile);
            if (Ui.KeptTab == 1) { tabs.SelectedIndex = 1; ShowTab(1); }
            Ui.KeptTab = 0; Ui.KeptDecFile = "";

            DragEnter += new DragEventHandler(OnDragEnter);
            DragDrop += new DragEventHandler(OnDragDrop);
            list.DragEnter += new DragEventHandler(OnDragEnter);
            list.DragDrop += new DragEventHandler(OnDragDrop);
            btnAddF.Click += new EventHandler(OnAddFiles);
            btnAddD.Click += new EventHandler(OnAddFolder);
            btnRem.Click += new EventHandler(OnRemove);
            btnKf.Click += new EventHandler(OnBrowseKf);
            pw1.Box.TextChanged += new EventHandler(OnPwChanged);
            btnGo.Click += new EventHandler(OnGo);
            btnCancel.Click += new EventHandler(delegate { Close(); });
        }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            if (e.KeyCode == Keys.Enter && pageOpts.Visible && !busy) { btnGo.PerformClick(); e.Handled = true; e.SuppressKeyPress = true; }
            else if (e.KeyCode == Keys.Enter && pageAlt.Visible && !busy) { dec.Go(); e.Handled = true; e.SuppressKeyPress = true; }
            base.OnKeyDown(e);
        }

        private void ShowTab(int i)
        {
            pageOpts.Visible = i == 0;
            pageAlt.Visible = i == 1;
            subtitle = Ui.T(i == 0 ? "g_sub_enc" : "g_sub_dec");
            Text = Ui.T(i == 0 ? "g_title_enc" : "g_title_dec");
            Invalidate();
        }

        protected override void HandleClosing(object s, FormClosingEventArgs e)
        {
            base.HandleClosing(s, e);
            if (!e.Cancel) dec.Dispose();
        }

        protected override void KeepState()
        {
            string[] items = new string[list.Items.Count];
            for (int i = 0; i < items.Length; i++) items[i] = (string)list.Items[i];
            Ui.KeptItems = items;
            Ui.KeptTab = tabs.SelectedIndex;
            Ui.KeptDecFile = dec.SelectedFile;
        }

        private void AddItem(string p)
        {
            if (string.IsNullOrEmpty(p)) return;
            p = p.Trim().Trim('"');
            if (p.Length == 0) return;
            if (!File.Exists(p) && !Directory.Exists(p)) return;
            string full = Path.GetFullPath(p);
            if (full.Length > 3) full = full.TrimEnd('\\');
            if (Ui.Forbidden(full)) { refused.Add(full); return; }
            for (int i = 0; i < list.Items.Count; i++)
                if (string.Equals((string)list.Items[i], full, StringComparison.OrdinalIgnoreCase)) return;
            list.Items.Add(full);
        }

        // system locations are collected while a batch is added and reported in ONE message
        private List<string> refused = new List<string>();

        private void ShowRefused()
        {
            if (refused.Count == 0) return;
            StringBuilder sb = new StringBuilder(Ui.T("forbidden"));
            sb.Append("\r\n");
            for (int i = 0; i < refused.Count && i < 12; i++) sb.Append("\r\n").Append(refused[i]);
            if (refused.Count > 12) sb.Append("\r\n...");
            refused.Clear();
            Warn(sb.ToString());
        }

        private void OnDragEnter(object s, DragEventArgs e)
        {
            if (!busy && e.Data.GetDataPresent(DataFormats.FileDrop)) e.Effect = DragDropEffects.Copy;
            else e.Effect = DragDropEffects.None;
        }

        private void OnDragDrop(object s, DragEventArgs e)
        {
            if (busy) return;
            string[] files = (string[])e.Data.GetData(DataFormats.FileDrop);
            if (pageAlt.Visible)
            {
                if (files != null && files.Length > 0) dec.SetFile(files[0]);
                return;
            }
            if (files != null) for (int i = 0; i < files.Length; i++) AddItem(files[i]);
            ShowRefused();
        }

        private void OnAddFiles(object s, EventArgs e)
        {
            OpenFileDialog d = new OpenFileDialog();
            d.Multiselect = true;
            d.CheckFileExists = true;
            if (d.ShowDialog(this) == DialogResult.OK)
            {
                for (int i = 0; i < d.FileNames.Length; i++) AddItem(d.FileNames[i]);
                ShowRefused();
            }
        }

        private void OnAddFolder(object s, EventArgs e)
        {
            string[] picked = FolderPicker.Pick(Handle, Ui.T("g_add_folder").TrimEnd('.'));
            if (picked != null)
            {
                for (int i = 0; i < picked.Length; i++) AddItem(picked[i]);
                ShowRefused();
                return;
            }
            // no modern dialog on this Windows: the old one
            FolderBrowserDialog d = new FolderBrowserDialog();
            if (d.ShowDialog(this) == DialogResult.OK) { AddItem(d.SelectedPath); ShowRefused(); }
        }

        private void OnRemove(object s, EventArgs e)
        {
            for (int i = list.SelectedIndices.Count - 1; i >= 0; i--) list.Items.RemoveAt(list.SelectedIndices[i]);
        }

        private void OnBrowseKf(object s, EventArgs e)
        {
            string f = Ui.PickFile(this, Ui.T("kf_pick_title"));
            if (f != null) kf.Text = f;
        }

        private int StrengthOf(string pw)
        {
            SecureString ss = Ui.ToSecure(pw);
            int n = Core.Strength(ss);
            ss.Dispose();
            if (n < 0) n = 0;
            if (n > 4) n = 4;
            return n;
        }

        private void OnPwChanged(object s, EventArgs e)
        {
            if (pw1.Text.Length == 0) { strength.Text = ""; return; }
            int n = StrengthOf(pw1.Text);
            strength.Text = Ui.TF("pw_strength", Ui.T("strength" + n), null);
            strength.ForeColor = n <= 1 ? Theme.Danger : (n == 2 ? Theme.Warn : Theme.Ok);
        }

        private void OnGo(object s, EventArgs e)
        {
            if (busy) return;
            if (list.Items.Count == 0) { Warn(Ui.T("empty")); return; }

            string p1 = pw1.Text;
            if (p1.Length > 0)
            {
                if (p1 != pw2.Text) { Warn(Ui.T("pw_mismatch")); return; }
                if (StrengthOf(p1) <= 1 && !Confirm(Ui.T("pw_weak"))) return;
            }
            string kfPath = kf.Text.Trim().Trim('"');
            if (kfPath.Length > 0 && !File.Exists(kfPath)) { Warn(Ui.TF("kf_missing", kfPath, null)); return; }
            if (p1.Length == 0 && kfPath.Length == 0)
            {
                if (!Confirm(Ui.T("no_enc") + "\r\n\r\n" + Ui.T("g_continue"))) return;
            }

            string[] items = new string[list.Items.Count];
            for (int i = 0; i < items.Length; i++) items[i] = (string)list.Items[i];

            string first = items[0];
            string leaf = Path.GetFileName(first.TrimEnd('\\'));
            if (string.IsNullOrEmpty(leaf)) leaf = "Drive_" + first.Substring(0, 1);
            string baseName = File.Exists(first) ? Path.GetFileNameWithoutExtension(leaf) : leaf;
            if (items.Length > 1) baseName = string.Format("{0}_and_{1}_more", baseName, items.Length - 1);
            string outDir = Path.GetDirectoryName(first.TrimEnd('\\'));
            if (string.IsNullOrEmpty(outDir)) outDir = first;
            string outCmd = Path.Combine(outDir, baseName + "_decrypt.cmd");
            if (File.Exists(outCmd) && !Confirm(Ui.TF("exists_q", outCmd, null))) return;

            SecureString pw = Ui.ToSecure(p1);
            byte[] secret;
            try { secret = Core.MakeSecret(pw, kfPath.Length > 0 ? Path.GetFullPath(kfPath) : null); }
            catch (Exception ex) { Warn(Ui.ErrorText(ex)); return; }
            finally { pw.Dispose(); }
            pw1.Text = ""; pw2.Text = "";

            int delMode = del.SelectedIndex;
            bool usesPw = p1.Length > 0;
            bool usesKf = kfPath.Length > 0;
            bool gzip = true;
            if (items.Length == 1 && File.Exists(first))
            {
                string ext = Path.GetExtension(first).ToLowerInvariant();
                for (int i = 0; i < Ui.CompressedExt.Length; i++) if (Ui.CompressedExt[i] == ext) gzip = false;
            }
            // very large data: the GZip component of older .NET versions cannot handle more than 4 GB
            if (gzip && Core.TotalSize(items, Core.GzipLimit) >= Core.GzipLimit) gzip = false;

            busy = true;
            ShowWork();
            HookSinks();
            Thread t = new Thread(new ThreadStart(delegate { Work(items, outCmd, gzip, secret, usesPw, usesKf, delMode); }));
            t.Start();
        }

        private void Work(string[] items, string outCmd, bool gzip, byte[] secret, bool usesPw, bool usesKf, int delMode)
        {
            string part = outCmd + ".part";
            string error = null;
            string text = null;
            bool ok = false;
            Stopwatch sw = Stopwatch.StartNew();
            try
            {
                if (File.Exists(part)) File.Delete(part);
                File.WriteAllText(part, head, Encoding.ASCII);

                Core.Encode(items, part, outCmd, gzip, secret, usesPw, usesKf, Core.DefaultIterations, delMode > 0);
                // an older file of the same name is replaced only now, when the new one is complete
                if (File.Exists(outCmd)) { File.SetAttributes(outCmd, FileAttributes.Normal); File.Delete(outCmd); }
                File.Move(part, outCmd);
                File.SetAttributes(outCmd, FileAttributes.ReadOnly);
                sw.Stop();

                StringBuilder sb = new StringBuilder();
                sb.AppendLine(Ui.TF("src_info", Core.LastCount, Ui.FmtSize(Core.LastTotal)));
                sb.AppendLine(Ui.TF("src_sha", Core.LastSha, null));
                string mode = secret == null ? Ui.T("mode1") : Ui.T("mode2");
                mode += ", " + (gzip ? Ui.T("comp_on") : Ui.T("comp_off"));
                sb.AppendLine(Ui.TF("mode_label", mode, null));
                for (int i = 0; i < Core.Skipped.Count; i++) sb.AppendLine(Ui.MarkWarn + Ui.TF("skipped", Core.Skipped[i], null));
                if (delMode > 0) sb.AppendLine(Ui.T("verified"));
                sb.AppendLine(Ui.TF("out_info", outCmd, Ui.FmtSize(Core.LastOutSize)));
                if (Core.LastOutSize >= 4294967296L) sb.AppendLine(Ui.MarkWarn + Ui.T("big_warn"));
                sb.AppendLine(Ui.TF("elapsed", Ui.FmtDuration(sw.Elapsed.TotalSeconds), null));

                if (delMode > 0)
                {
                    bool inside = false;
                    for (int i = 0; i < items.Length; i++)
                        if (Directory.Exists(items[i]) && outCmd.StartsWith(items[i].TrimEnd('\\') + "\\", StringComparison.OrdinalIgnoreCase)) inside = true;
                    if (inside || Core.Skipped.Count > 0) sb.AppendLine(Ui.MarkWarn + Ui.T("del_skip"));
                    else
                    {
                        try
                        {
                            Core.DeleteItems(items, delMode == 2);
                            if (Core.DeleteKept.Count > 0)
                            {
                                sb.AppendLine(Ui.MarkWarn + Ui.TF("del_kept", Core.DeleteKept.Count, null));
                                for (int i = 0; i < Core.DeleteKept.Count; i++) sb.AppendLine(Ui.MarkWarn + "  " + Core.DeleteKept[i]);
                            }
                            if (Core.DeleteFailed.Count == 0) sb.AppendLine(Ui.T("del_ok"));
                            else
                            {
                                sb.AppendLine(Ui.MarkWarn + Ui.TF("del_partial", Core.DeleteFailed.Count, null));
                                for (int i = 0; i < Core.DeleteFailed.Count; i++) sb.AppendLine(Ui.MarkWarn + "  " + Core.DeleteFailed[i]);
                                sb.AppendLine(Ui.MarkWarn + Ui.T("del_partial_hint"));
                            }
                        }
                        catch (Exception dx) { sb.AppendLine(Ui.MarkBad + Ui.TF("del_fail", dx.Message, null)); }
                    }
                }
                text = sb.ToString();
                ok = true;
            }
            catch (Exception ex)
            {
                try { if (File.Exists(part)) File.Delete(part); } catch { }
                error = Ui.ErrorText(ex);
            }
            finally
            {
                if (secret != null) Array.Clear(secret, 0, secret.Length);
                UnhookSinks();
            }

            try
            {
                BeginInvoke(new MethodInvoker(delegate
                {
                    if (ok) ShowResult(true, Ui.T("success"), text, outCmd);
                    else ShowResult(false, error, null, null);
                }));
            }
            catch { }
        }

    }

    // ---------------------------------------------------------------- setup window

    internal class SetupForm : GlassForm
    {
        public SetupForm(bool installed, string message, bool messageOk) : base(Ui.T("g_title_setup"), Ui.T("g_sub_setup"), 404)
        {
            Card a = new Card(); a.SetBounds(20, 0, 580, 132); pageOpts.Controls.Add(a);
            a.Controls.Add(new Caption(Ui.T("g_st_cap"), 18, 12, 544));
            Label st = MakeLabel(a, installed ? Ui.T("g_st_yes") : Ui.T("g_st_no"), 18, 34, 340, Theme.Title, installed ? Theme.Ok : Theme.Warn);
            st.Height = 40;
            // use the program without installing it: opens the encrypt window
            // the width follows the text (other languages are longer), with the same side margin as everything else
            FlatButton free = new FlatButton(Ui.T("g_btn_free"), false);
            int dw = (int)Math.Ceiling(TextRenderer.MeasureText(Ui.T("g_btn_free"), Theme.Bold).Width / Theme.F) + 44;
            if (dw < 150) dw = 150;
            if (dw > 280) dw = 280;
            free.SetBounds(580 - 24 - dw, 27, dw, 36);
            st.Width = 580 - 24 - dw - 18 - 8;
            a.Controls.Add(free);
            free.Click += new EventHandler(delegate { Ui.SetupAction = 3; Close(); });
            Label hint = MakeLabel(a, Ui.T("use_hint1") + " " + Ui.T("use_hint2"), 18, 76, 544, Theme.Body, Theme.Dim);
            hint.Height = 44;

            Card b = new Card(); b.SetBounds(20, 144, 580, 112); pageOpts.Controls.Add(b);
            Label what = MakeLabel(b, Ui.T("install_menu"), 18, 14, 544, Theme.Body, Theme.Text);
            what.Height = 40;
            Label msg = MakeLabel(b, message == null ? "" : message, 18, 62, 544, Theme.Bold, messageOk ? Theme.Ok : Theme.Danger);
            msg.Height = 40;

            FlatButton un = new FlatButton(Ui.T("g_btn_uninstall"), false);
            un.SetBounds(20, 272, 150, 38);
            un.Enabled = installed;
            FlatButton close = new FlatButton(Ui.T("g_close"), false);
            close.SetBounds(300, 272, 100, 38);
            FlatButton go = new FlatButton(installed ? Ui.T("g_btn_update") : Ui.T("g_btn_install"), true);
            go.SetBounds(410, 272, 190, 38);
            pageOpts.Controls.Add(un); pageOpts.Controls.Add(close); pageOpts.Controls.Add(go);

            go.Click += new EventHandler(delegate { Ui.SetupAction = 1; Close(); });
            un.Click += new EventHandler(delegate
            {
                if (Confirm(Ui.T("g_confirm_un"))) { Ui.SetupAction = 2; Close(); }
            });
            close.Click += new EventHandler(delegate { Close(); });
            ActiveControl = go;
        }
    }

    // ---------------------------------------------------------------- decrypt window

    // The decrypt options page. It is used by the decrypt window of every *_decrypt.cmd (picker = false: the file is the
    // one that was started) and by the "Decrypt" tab of SecureEncrypt.cmd (picker = true: the user chooses the file).
    internal class DecryptPanel
    {
        private GlassForm host;
        private bool picker;
        private Archive arc;
        private string dest;
        private string selected = "";
        private Field pw, kf, fileBox;
        private Label info;
        private FlatButton btnKf, btnGo, btnCancel, btnPick;
        private int attempts;
        private bool checking;

        internal string SelectedFile { get { return selected; } }

        public DecryptPanel(GlassForm host, Panel page, bool picker, string selfPath, long dataStart)
        {
            this.host = host;
            this.picker = picker;
            int rowH = picker ? 268 : 180;

            // two columns like the browser page: the file on the left, the password / key file on the right
            Card a = new Card(); a.SetBounds(20, 0, 420, rowH); page.Controls.Add(a);
            Card b = new Card(); b.SetBounds(452, 0, 428, rowH); page.Controls.Add(b);

            if (picker)
            {
                a.Controls.Add(new Caption(Ui.T("g_dec_pick"), 18, 12, 384));
                fileBox = new Field(false); fileBox.SetBounds(18, 36, 384, 36);
                fileBox.Box.ReadOnly = true; fileBox.Box.TabStop = false; fileBox.TabStop = false;
                a.Controls.Add(fileBox);
                btnPick = new FlatButton(Ui.T("g_dec_choose"), false); btnPick.SetBounds(18, 82, 170, 36);
                a.Controls.Add(btnPick);
                Label hint = host.MakeLabel(a, Ui.T("g_dec_hint"), 18, 132, 384, Theme.Small, Theme.Dim);
                hint.Height = 80;
                Card c = new Card(); c.SetBounds(20, 280, 860, 78); page.Controls.Add(c);
                info = host.MakeLabel(c, "", 18, 14, 824, Theme.Bold, Theme.Text);
                info.Height = 54;
            }
            else
            {
                a.Controls.Add(new Caption(Ui.TF("file", Path.GetFileName(selfPath), null), 18, 12, 384));
                info = host.MakeLabel(a, "", 18, 40, 384, Theme.Bold, Theme.Text);
                info.Height = 120;
            }

            b.Controls.Add(new Caption(Ui.T(picker ? "g_dec_pw" : "t_pw"), 18, 12, 392));
            pw = new Field(true); pw.SetBounds(18, 34, 392, 36); b.Controls.Add(pw);
            b.Controls.Add(new Caption(Ui.T(picker ? "g_dec_kf" : "g_kf"), 18, 84, 392));
            kf = new Field(false); kf.SetBounds(18, 108, 280, 36);
            btnKf = new FlatButton(Ui.T("g_browse"), false); btnKf.SetBounds(306, 108, 104, 36);
            b.Controls.Add(kf); b.Controls.Add(btnKf);

            int by = picker ? 410 : 196;
            btnCancel = new FlatButton(Ui.T("g_cancel"), false); btnCancel.SetBounds(630, by, 110, 38);
            btnGo = new FlatButton(Ui.T("g_decrypt"), true); btnGo.SetBounds(750, by, 130, 38);
            page.Controls.Add(btnCancel); page.Controls.Add(btnGo);

            btnKf.Click += new EventHandler(OnBrowseKf);
            btnGo.Click += new EventHandler(OnGo);
            btnCancel.Click += new EventHandler(delegate { host.Close(); });
            if (picker) btnPick.Click += new EventHandler(OnPick);

            if (picker)
            {
                info.ForeColor = Theme.Dim;
                info.Text = Ui.T("g_dec_none");
                pw.Enabled = false; kf.Enabled = false; btnKf.Enabled = false; btnGo.Enabled = false;
            }
            else Load(selfPath, dataStart);
        }

        internal void Go() { btnGo.PerformClick(); }

        internal void Dispose()
        {
            if (arc != null) arc.Clear();
        }

        // opens the archive and shows what it needs; throws when the file is not a SecureEncrypt file
        private void Load(string path, long dataStart)
        {
            Archive na = Archive.Open(path, dataStart);
            if (arc != null) arc.Clear();
            arc = na;
            dest = Path.GetDirectoryName(path);
            attempts = 0;
            pw.Text = ""; kf.Text = "";
            info.ForeColor = Theme.Text;
            btnGo.Enabled = true;
            btnCancel.Text = Ui.T("g_cancel");
            if (arc.Mode != 2)
            {
                info.Text = Ui.T("enc_none");
                pw.Enabled = false; kf.Enabled = false; btnKf.Enabled = false;
            }
            else
            {
                string n;
                if (arc.UsesPassword && arc.UsesKeyFile) n = Ui.T("n_both");
                else if (arc.UsesKeyFile) n = Ui.T("n_kf");
                else n = Ui.T("n_pw");
                info.Text = Ui.TF("needs", n, null);
                pw.Enabled = arc.UsesPassword;
                kf.Enabled = arc.UsesKeyFile;
                btnKf.Enabled = arc.UsesKeyFile;
            }
        }

        // picker mode: a *_decrypt.cmd was chosen or dropped
        internal void SetFile(string p)
        {
            if (host.busy || checking || string.IsNullOrEmpty(p)) return;
            try
            {
                p = p.Trim().Trim('"');
                if (!File.Exists(p)) return;
                string full = Path.GetFullPath(p);
                long ds = FindDataStart(full);
                if (ds < 0) { host.Warn(Ui.T("g_dec_bad")); return; }
                Load(full, ds);
                selected = full;
                fileBox.Text = full;
                fileBox.Box.Select(0, 0);
            }
            catch (Exception ex) { host.Warn(Ui.ErrorText(ex)); }
        }

        // the text part of a *_decrypt.cmd ends with a marker line; the encrypted data starts right after it
        private static long FindDataStart(string path)
        {
            byte[] buf = new byte[262144];
            int n;
            using (FileStream fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite)) n = fs.Read(buf, 0, buf.Length);
            string txt = Encoding.GetEncoding(28591).GetString(buf, 0, n);
            int e = txt.IndexOf("#PS_" + "END" + "\r\n", StringComparison.Ordinal);
            if (e < 0) return -1;
            return e + 9;
        }

        private void OnPick(object s, EventArgs e)
        {
            OpenFileDialog d = new OpenFileDialog();
            d.Title = Ui.T("g_dec_choose").TrimEnd('.');
            d.CheckFileExists = true;
            d.Multiselect = false;
            d.Filter = "*_decrypt.cmd|*_decrypt.cmd|*.cmd|*.cmd";
            if (d.ShowDialog(host) == DialogResult.OK) SetFile(d.FileName);
        }

        private void OnBrowseKf(object s, EventArgs e)
        {
            string f = Ui.PickFile(host, Ui.T("kf_pick_title"));
            if (f != null) kf.Text = f;
        }

        private void OnGo(object s, EventArgs e)
        {
            if (arc == null || host.busy || checking || attempts >= 3) return;
            byte[] secret = null;
            if (arc.Mode == 2)
            {
                string kfPath = null;
                if (arc.UsesKeyFile)
                {
                    string k = kf.Text.Trim().Trim('"');
                    if (k.Length == 0 || !File.Exists(k)) { host.Warn(Ui.TF("kf_missing", k, null)); return; }
                    kfPath = Path.GetFullPath(k);
                }
                SecureString ss = Ui.ToSecure(arc.UsesPassword ? pw.Text : "");
                bool unlocked;
                checking = true;
                btnGo.Enabled = false;
                host.Cursor = Cursors.WaitCursor;
                info.ForeColor = Theme.Dim;
                info.Text = Ui.T("kdf");
                info.Refresh();
                Core.StatusSink = new StatusHandler(delegate(string x) { });
                try
                {
                    secret = Core.MakeSecret(ss, kfPath);
                    unlocked = secret != null && arc.Unlock(secret);
                }
                catch (Exception ex)
                {
                    info.ForeColor = Theme.Danger;
                    info.Text = Ui.ErrorText(ex);
                    return;
                }
                finally { ss.Dispose(); host.Cursor = Cursors.Default; Core.StatusSink = null; checking = false; btnGo.Enabled = attempts < 3; }
                if (!unlocked)
                {
                    if (secret != null) Array.Clear(secret, 0, secret.Length);
                    attempts++;
                    pw.Text = "";
                    info.ForeColor = Theme.Danger;
                    info.Text = Ui.TF("wrong", attempts, 3);
                    if (attempts >= 3)
                    {
                        // out of attempts: lock the inputs, say so clearly, only Close is left
                        btnGo.Enabled = false; pw.Enabled = false; kf.Enabled = false; btnKf.Enabled = false;
                        info.Text = Ui.T("g_toomany");
                        btnCancel.Text = Ui.T("g_close");
                        host.Warn(Ui.T("g_toomany"));
                    }
                    return;
                }
                pw.Text = "";
            }

            host.busy = true;
            host.ShowWork();
            host.HookSinks();
            // the conflict question is asked from the worker thread; it is shown on the UI thread
            Core.ConflictSink = new ConflictHandler(delegate(string target)
            {
                int r = 0;
                try { host.Invoke(new MethodInvoker(delegate { r = Ui.AskConflict(host, target); })); } catch { }
                return r;
            });
            Thread t = new Thread(new ThreadStart(delegate { Work(secret); }));
            t.Start();
        }

        private void Work(byte[] secret)
        {
            string error = null;
            string text = null;
            bool ok = false;
            try
            {
                Stopwatch sw = Stopwatch.StartNew();
                arc.Extract(dest);
                sw.Stop();
                StringBuilder sb = new StringBuilder();
                sb.AppendLine(Ui.TF("sha", arc.ShaHex, null));
                sb.AppendLine(arc.ShaOk ? Ui.T("sha_ok") : Ui.MarkBad + Ui.T("sha_fail"));
                sb.AppendLine(Ui.TF("done", arc.Count, Path.GetFullPath(dest)));
                sb.AppendLine(Ui.TF("elapsed", Ui.FmtDuration(sw.Elapsed.TotalSeconds), null));
                text = sb.ToString();
                ok = arc.ShaOk;
                if (!ok) error = Ui.T("sha_fail");
            }
            catch (Exception ex) { error = Ui.ErrorText(ex); }
            finally
            {
                if (secret != null) Array.Clear(secret, 0, secret.Length);
                host.UnhookSinks();
            }
            try
            {
                host.BeginInvoke(new MethodInvoker(delegate
                {
                    host.ShowResult(ok, ok ? Ui.T("g_done_dec") : error, text, dest);
                }));
            }
            catch { }
        }
    }

    internal class DecryptForm : GlassForm
    {
        private DecryptPanel panel;

        public DecryptForm(string selfPath, long dataStart) : base(Ui.T("g_title_dec"), Ui.T("g_sub_dec"), 900, 330)
        {
            panel = new DecryptPanel(this, pageOpts, false, selfPath, dataStart);
        }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            if (e.KeyCode == Keys.Enter && pageOpts.Visible && !busy) { panel.Go(); e.Handled = true; e.SuppressKeyPress = true; }
            base.OnKeyDown(e);
        }

        protected override void HandleClosing(object s, FormClosingEventArgs e)
        {
            base.HandleClosing(s, e);
            if (!e.Cancel) panel.Dispose();
        }
    }
}
