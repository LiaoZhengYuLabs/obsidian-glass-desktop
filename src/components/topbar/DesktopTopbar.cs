using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

namespace ObsidianDesktopTopbar
{
    internal static class Program
    {
        private static Mutex instanceMutex;

        [DllImport("user32.dll")]
        private static extern bool SetProcessDpiAwarenessContext(IntPtr value);

        [STAThread]
        private static void Main()
        {
            bool created;
            instanceMutex = new Mutex(true, "Local\\ObsidianDesktopTopbar", out created);
            if (!created) return;

            SetProcessDpiAwarenessContext(new IntPtr(-4));
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new OriginalStyleTopbar());
        }
    }

    internal sealed class MenuItem
    {
        internal readonly string Label;
        internal readonly string ToolTip;
        internal readonly Action Click;
        internal Rectangle Bounds;

        internal MenuItem(string label, string toolTip, Action click)
        {
            Label = label;
            ToolTip = toolTip;
            Click = click;
        }
    }

    internal sealed class OriginalStyleTopbar : Form
    {
        private const int BarHeight = 64;
        private const int WsExToolWindow = 0x00000080;
        private const int WsExNoActivate = 0x08000000;
        private static readonly IntPtr HwndTopmost = new IntPtr(-1);
        private const uint SwpShowWindow = 0x0040;
        private readonly List<MenuItem> rightItems = new List<MenuItem>();
        private readonly ToolTip toolTips = new ToolTip();
        private readonly System.Windows.Forms.Timer statusTimer = new System.Windows.Forms.Timer();
        private readonly Font menuFont = new Font("Microsoft YaHei UI", 28.0f, FontStyle.Regular, GraphicsUnit.Pixel);
        private readonly Font appFont = new Font("Microsoft YaHei UI", 28.0f, FontStyle.Bold, GraphicsUnit.Pixel);
        private MenuItem hoveredItem;

        [DllImport("user32.dll")]
        private static extern bool SetWindowPos(IntPtr hWnd, IntPtr insertAfter, int x, int y, int cx, int cy, uint flags);

        [DllImport("user32.dll")]
        private static extern void keybd_event(byte virtualKey, byte scanCode, uint flags, UIntPtr extraInfo);

        private const byte VkMenu = 0x12;
        private const uint KeyUpFlag = 0x0002;

        internal OriginalStyleTopbar()
        {
            FormBorderStyle = FormBorderStyle.None;
            ShowInTaskbar = false;
            TopMost = true;
            StartPosition = FormStartPosition.Manual;
            BackColor = Color.Black;
            DoubleBuffered = true;
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint, true);

            BuildMenu();
            statusTimer.Interval = 10000;
            statusTimer.Tick += delegate { Invalidate(); };
        }

        protected override bool ShowWithoutActivation
        {
            get { return true; }
        }

        protected override CreateParams CreateParams
        {
            get
            {
                CreateParams parameters = base.CreateParams;
                parameters.ExStyle |= WsExToolWindow | WsExNoActivate;
                return parameters;
            }
        }

        protected override void OnLoad(EventArgs e)
        {
            base.OnLoad(e);
            Rectangle screen = Screen.PrimaryScreen.Bounds;
            Location = new Point(screen.Left, screen.Top);
            Size = new Size(screen.Width, BarHeight);
            SetWindowPos(Handle, HwndTopmost, screen.Left, screen.Top, screen.Width, BarHeight, SwpShowWindow);
            statusTimer.Start();
            Log("原始样式右侧顶栏已启动。");
        }

        protected override void OnFormClosed(FormClosedEventArgs e)
        {
            statusTimer.Stop();
            menuFont.Dispose();
            appFont.Dispose();
            base.OnFormClosed(e);
        }

        private void BuildMenu()
        {
            rightItems.Add(new MenuItem("○", "打开 ChatGPT", OpenChatGpt));
            rightItems.Add(new MenuItem("ChatGPT", "打开 ChatGPT", OpenChatGpt));
            rightItems.Add(new MenuItem("文件", "打开当前应用的文件菜单", delegate { SendAppMenu((byte)'F'); }));
            rightItems.Add(new MenuItem("编辑", "打开当前应用的编辑菜单", delegate { SendAppMenu((byte)'E'); }));
            rightItems.Add(new MenuItem("视图", "打开当前应用的视图菜单", delegate { SendAppMenu((byte)'V'); }));
            rightItems.Add(new MenuItem("帮助", "打开当前应用的帮助菜单", delegate { SendAppMenu((byte)'H'); }));
            rightItems.Add(new MenuItem("X", "打开 X", delegate { Open("https://x.com"); }));
            rightItems.Add(new MenuItem("GitHub", "打开 GitHub", delegate { Open("https://github.com"); }));
            rightItems.Add(new MenuItem("", "查看电源设置", delegate { Open("ms-settings:powersleep"); }));
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            e.Graphics.Clear(Color.Black);
            e.Graphics.TextRenderingHint = System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;
            LayoutRightItems(e.Graphics);

            for (int index = 0; index < rightItems.Count; index++)
            {
                MenuItem item = rightItems[index];
                string label = index == rightItems.Count - 1 ? GetBatteryLabel() : item.Label;
                Font font = index == 1 ? appFont : menuFont;
                Color color = Color.FromArgb(242, 242, 242);
                TextRenderer.DrawText(
                    e.Graphics,
                    label,
                    font,
                    item.Bounds,
                    color,
                    TextFormatFlags.NoPadding | TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis);
            }
        }

        private void LayoutRightItems(Graphics graphics)
        {
            int layoutWidth = GetLayoutWidth(graphics);
            int right = layoutWidth - 28;
            for (int index = rightItems.Count - 1; index >= 0; index--)
            {
                MenuItem item = rightItems[index];
                string label = index == rightItems.Count - 1 ? GetBatteryLabel() : item.Label;
                Font font = index == 1 ? appFont : menuFont;
                int width = Math.Max(52, TextRenderer.MeasureText(label, font).Width + 30);
                right -= width;
                item.Bounds = new Rectangle(right, 4, width, 56);
                right -= 12;
            }
        }

        private static int GetLayoutWidth(Graphics graphics)
        {
            int width = (int)Math.Round(graphics.VisibleClipBounds.Width * 96.0 / Math.Max(96.0f, graphics.DpiX));
            return Math.Max(900, width);
        }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            base.OnMouseMove(e);
            MenuItem nextItem = FindItem(e.Location);
            if (nextItem == hoveredItem) return;
            hoveredItem = nextItem;
            Cursor = hoveredItem == null ? Cursors.Default : Cursors.Hand;
            toolTips.SetToolTip(this, hoveredItem == null ? String.Empty : hoveredItem.ToolTip);
        }

        protected override void OnMouseLeave(EventArgs e)
        {
            base.OnMouseLeave(e);
            if (hoveredItem == null) return;
            hoveredItem = null;
            Cursor = Cursors.Default;
            toolTips.SetToolTip(this, String.Empty);
        }

        protected override void OnMouseUp(MouseEventArgs e)
        {
            base.OnMouseUp(e);
            if (e.Button != MouseButtons.Left) return;
            MenuItem item = FindItem(e.Location);
            if (item == null) return;
            try
            {
                item.Click();
                Log("已执行顶栏操作: " + item.Label);
            }
            catch (Exception error)
            {
                Log("顶栏操作失败: " + error.Message);
            }
        }

        private MenuItem FindItem(Point point)
        {
            for (int index = 0; index < rightItems.Count; index++)
            {
                if (rightItems[index].Bounds.Contains(point)) return rightItems[index];
            }
            return null;
        }

        private static void SendAppMenu(byte key)
        {
            keybd_event(VkMenu, 0, 0, UIntPtr.Zero);
            keybd_event(key, 0, 0, UIntPtr.Zero);
            keybd_event(key, 0, KeyUpFlag, UIntPtr.Zero);
            keybd_event(VkMenu, 0, KeyUpFlag, UIntPtr.Zero);
        }

        private static string GetBatteryLabel()
        {
            PowerStatus power = SystemInformation.PowerStatus;
            int value = (int)(power.BatteryLifePercent * 100.0f);
            if (value < 0 || value > 100) return "电量 --";
            string source = power.PowerLineStatus == PowerLineStatus.Online ? "接电" : "电池";
            return source + " " + value + "%";
        }

        private static void OpenChatGpt()
        {
            string shortcut = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "AppShortcuts\\DockLaunchers\\ChatGPT.lnk");
            if (File.Exists(shortcut))
            {
                Open(shortcut);
                return;
            }
            Open("https://chatgpt.com");
        }

        private static void Open(string target)
        {
            ProcessStartInfo startInfo = new ProcessStartInfo();
            startInfo.FileName = target;
            startInfo.UseShellExecute = true;
            Process.Start(startInfo);
        }

        private static void Log(string message)
        {
            try
            {
                string root = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "ObsidianDesktopTopbar");
                Directory.CreateDirectory(root);
                File.AppendAllText(Path.Combine(root, "topbar.log"), DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + " " + message + Environment.NewLine);
            }
            catch { }
        }
    }
}
