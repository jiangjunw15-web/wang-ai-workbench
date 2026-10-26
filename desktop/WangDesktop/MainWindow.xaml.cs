using System;
using System.IO;
using System.Net.Http;
using System.Windows.Input;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Media;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.Wpf;

namespace WangDesktop;

/// <summary>
/// 王将军AI工作台 — 桌面客户端。
///
/// 平台本体跑在本机 WSL 容器里（http://localhost:3000），本程序是它的原生桌面外壳：
/// 无地址栏、无标签页，自绘冰蓝标题栏，附带系统托盘常驻与一键服务自检。
/// </summary>
public partial class MainWindow : Window
{
    private const string PlatformUrl = "http://localhost:3000";

    private readonly HttpClient _http = new()
    {
        Timeout = TimeSpan.FromSeconds(5),
        // 相对 URI 必须有 BaseAddress；探测目标固定为本机平台。
        BaseAddress = new Uri(PlatformUrl + "/"),
    };
    private System.Windows.Forms.NotifyIcon? _tray;
    private bool _exiting;
    private bool _platformUp;

    public MainWindow()
    {
        InitializeComponent();
        Loaded += MainWindow_Loaded;
        Closing += MainWindow_Closing;
        StateChanged += (_, _) => RefreshChrome();
    }

    // ----------------------------------------------------------------- 加载

    private async void MainWindow_Loaded(object sender, RoutedEventArgs e)
    {
        SetupTray();
        await EnsurePlatformAsync();
        await InitBrowserAsync();
    }

    /// <summary>确保本机平台在跑：不通就拉起服务，然后等待就绪。</summary>
    private async Task EnsurePlatformAsync()
    {
        SetStatus("正在检查本机服务…", false);

        if (await PingAsync())
        {
            _platformUp = true;
            SetStatus("服务就绪", true);
            return;
        }

        SetStatus("服务未启动，正在拉起…", false);
        LoadingText.Text = "正在启动本机服务（首次启动可能需要一两分钟）…";
        try
        {
            StartPlatform();
        }
        catch (Exception ex)
        {
            LoadingText.Text = "无法启动本机服务：" + ex.Message;
            BtnRetry.Visibility = Visibility.Visible;
            return;
        }

        for (int i = 0; i < 60; i++)
        {
            await Task.Delay(2000);
            if (await PingAsync())
            {
                _platformUp = true;
                SetStatus("服务就绪", true);
                return;
            }
        }

        LoadingText.Text = "本机服务启动超时。确认 WSL 发行版 AutoGPT 正常运行。";
        BtnRetry.Visibility = Visibility.Visible;
    }

    private async Task<bool> PingAsync()
    {
        try
        {
            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(4));
            using var res = await _http.GetAsync("/", cts.Token);
            return res.StatusCode != System.Net.HttpStatusCode.BadGateway;
        }
        catch
        {
            return false;
        }
    }

    /// <summary>拉起本机服务（委托给固定脚本启动器，无命令行参数）。</summary>
    private static void StartPlatform() => ServiceLauncher.Launch();

    // ------------------------------------------------------------- WebView2

    private async Task InitBrowserAsync()
    {
        try
        {
            var userData = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "WangDesktop", "webview");
            Directory.CreateDirectory(userData);

            var env = await CoreWebView2Environment.CreateAsync(null, userData);
            await Browser.EnsureCoreWebView2Async(env);

            var settings = Browser.CoreWebView2.Settings;
            settings.AreDefaultContextMenusEnabled = true;
            settings.IsZoomControlEnabled = true;
            settings.IsStatusBarEnabled = false;
            settings.AreDevToolsEnabled = false;
            settings.IsWebMessageEnabled = true;
            settings.AreHostObjectsAllowed = false;

            Browser.CoreWebView2.NewWindowRequested += (_, e) =>
            {
                // 所有新窗口在应用内打开，保持单窗口体验
                e.Handled = true;
                Browser.CoreWebView2.Navigate(e.Uri.ToString());
            };

            Browser.CoreWebView2.HistoryChanged += (_, _) => Dispatcher.Invoke(UpdateNavigationButtons);
            Browser.CoreWebView2.NavigationCompleted += async (_, e) =>
            {
                if (e.IsSuccess)
                {
                    Browser.Visibility = Visibility.Visible;
                    LoadingPanel.Visibility = Visibility.Collapsed;
                    await ApplyBrandingAsync();
                }
                else
                {
                    LoadingText.Text = "页面载入失败：" + e.WebErrorStatus;
                    BtnRetry.Visibility = Visibility.Visible;
                }
            };

            Browser.CoreWebView2.WebMessageReceived += (_, e) =>
            {
                try
                {
                    var msg = e.TryGetWebMessageAsString();
                    if (msg.StartsWith("wang:status:", StringComparison.Ordinal))
                    {
                        FooterModels.Text = msg["wang:status:".Length..];
                    }
                }
                catch { /* 忽略来自页面的异常消息 */ }
            };

            // 品牌化：把平台内联的 AutoGPT 字标换成王将军字标。
            // 页面是 React 水合渲染，水合会把我们替换掉的元素换回去，
            // 因此文档创建时先埋一个 MutationObserver，导航完成后再补一次。
            await Browser.CoreWebView2.AddScriptToExecuteOnDocumentCreatedAsync(
                """
                (function () {
                  window.__wangSwap = function () {
                    document.querySelectorAll('svg').forEach(function (s) {
                      var a = (s.getAttribute('aria-label') || '').toLowerCase();
                      if (a.indexOf('logo') < 0) return;
                      if (s.dataset.wangDone) return;
                      s.dataset.wangDone = '1';
                      var img = document.createElement('img');
                      img.src = '/wang-wordmark.svg';
                      img.alt = '王将军AI工作台';
                      // 继承原 svg 的宽度类，并额外限制最大宽度，避免字标过大
                      img.className = s.getAttribute('class') || '';
                      img.style.maxWidth = '220px';
                      img.style.width = 'auto';
                      img.style.height = 'auto';
                      s.replaceWith(img);
                    });
                  };
                  window.__wangTimer = setInterval(window.__wangSwap, 400);
                  window.__wangSwap();
                })();
                """);

            Browser.CoreWebView2.Navigate(PlatformUrl + "/library");
        }
        catch (Exception ex)
        {
            var hint = ex.GetType().Name.Contains("WebView2", StringComparison.OrdinalIgnoreCase)
                ? "未检测到 Microsoft Edge WebView2 Runtime，请先安装后再启动。"
                : "界面内核启动失败：" + ex.Message;
            LoadingText.Text = hint;
            BtnRetry.Visibility = Visibility.Visible;
        }
    }

    /// <summary>
    /// 品牌替换兜底：文档创建脚本负责持续替换，这里在导航完成后再执行一次，
    /// 覆盖客户端路由切换后重新渲染出来的元素。
    /// </summary>
    private async Task ApplyBrandingAsync()
    {
        const string script = """
            (function () {
              try {
                if (window.__wangSwap) { window.__wangSwap(); return 'swap-ok'; }
                return 'no-swap-fn';
              } catch (err) { return 'ERR ' + err; }
            })();
            """;
        try
        {
            var r = await Browser.CoreWebView2.ExecuteScriptAsync(script);
            FooterModels.Text = "branding:" + r;
        }
        catch (Exception ex)
        {
            FooterModels.Text = "branding: " + ex.GetType().Name;
        }
    }

    // -------------------------------------------------------------- 托盘

    private void SetupTray()
    {
        var icon = LoadTrayIcon();
        _tray = new System.Windows.Forms.NotifyIcon
        {
            Icon = icon,
            Text = "王将军AI工作台",
            Visible = true,
            ContextMenuStrip = new System.Windows.Forms.ContextMenuStrip(),
        };
        _tray.ContextMenuStrip.Items.Add("显示主窗口", null, (_, _) => Dispatcher.Invoke(RestoreWindow));
        _tray.ContextMenuStrip.Items.Add("AI 排序管理", null, (_, _) =>
            Dispatcher.Invoke(() => Navigate("/wang/ai-order")));
        _tray.ContextMenuStrip.Items.Add("Magpie 连接", null, (_, _) =>
            Dispatcher.Invoke(() => Navigate("/wang/magpie")));
        _tray.ContextMenuStrip.Items.Add(new System.Windows.Forms.ToolStripSeparator());
        _tray.ContextMenuStrip.Items.Add("退出", null, (_, _) => Dispatcher.Invoke(ExitApp));
        _tray.DoubleClick += (_, _) => Dispatcher.Invoke(RestoreWindow);
    }

    private static Icon LoadTrayIcon()
    {
        try
        {
            var path = Path.Combine(AppContext.BaseDirectory, "Assets", "wang.ico");
            if (File.Exists(path)) return new Icon(path);
        }
        catch { /* 用系统图标兜底 */ }
        return System.Drawing.SystemIcons.Application;
    }

    private void Navigate(string path)
    {
        if (Browser.CoreWebView2 is null) return;
        Browser.CoreWebView2.Navigate(PlatformUrl + path);
        RestoreWindow();
    }

    private void RestoreWindow()
    {
        Show();
        if (WindowState == WindowState.Minimized) WindowState = WindowState.Normal;
        Activate();
    }

    private void ExitApp()
    {
        _exiting = true;
        if (_tray is not null)
        {
            _tray.Visible = false;
            _tray.Dispose();
            _tray = null;
        }
        System.Windows.Application.Current.Shutdown();
    }

    private void MainWindow_Closing(object? sender, System.ComponentModel.CancelEventArgs e)
    {
        if (_exiting) return;
        // 关闭窗口 = 收进托盘，服务继续跑
        e.Cancel = true;
        Hide();
        _tray?.ShowBalloonTip(2500, "王将军AI工作台",
            "已收进系统托盘，服务仍在运行。双击图标可重新打开。",
            System.Windows.Forms.ToolTipIcon.Info);
    }

    // ------------------------------------------------------------ 按钮 / 导航

    private void TitleBar_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ClickCount == 2)
        {
            BtnMaximize_Click(sender, e);
            return;
        }
        if (e.LeftButton == MouseButtonState.Pressed)
        {
            DragMove();
        }
    }

    private void UpdateNavigationButtons()
    {
        if (Browser.CoreWebView2 is null)
        {
            BtnBack.IsEnabled = false;
            BtnForward.IsEnabled = false;
            return;
        }
        BtnBack.IsEnabled = Browser.CoreWebView2.CanGoBack ||
                            !string.Equals(Browser.CoreWebView2.Source, PlatformUrl + "/library", StringComparison.OrdinalIgnoreCase);
        BtnForward.IsEnabled = Browser.CoreWebView2.CanGoForward;
    }

    private void BtnBack_Click(object sender, RoutedEventArgs e)
    {
        if (Browser.CoreWebView2 is null) return;
        if (Browser.CoreWebView2.CanGoBack)
            Browser.CoreWebView2.GoBack();
        else if (!Browser.CoreWebView2.Source.EndsWith("/library", StringComparison.OrdinalIgnoreCase))
            Browser.CoreWebView2.Navigate(PlatformUrl + "/library");
    }

    private void BtnForward_Click(object sender, RoutedEventArgs e)
    {
        if (Browser.CoreWebView2?.CanGoForward == true)
            Browser.CoreWebView2.GoForward();
    }

    protected override void OnPreviewKeyDown(System.Windows.Input.KeyEventArgs e)
    {
        if (e.Key == Key.F5)
        {
            Browser.CoreWebView2?.Reload();
            e.Handled = true;
            return;
        }
        if (e.SystemKey == Key.Left && Keyboard.Modifiers.HasFlag(ModifierKeys.Alt))
        {
            BtnBack_Click(this, new RoutedEventArgs());
            e.Handled = true;
            return;
        }
        if (e.SystemKey == Key.Right && Keyboard.Modifiers.HasFlag(ModifierKeys.Alt))
        {
            BtnForward_Click(this, new RoutedEventArgs());
            e.Handled = true;
            return;
        }
        base.OnPreviewKeyDown(e);
    }

    private void BtnReload_Click(object sender, RoutedEventArgs e)
        => Browser.CoreWebView2?.Reload();

    private void BtnMinimize_Click(object sender, RoutedEventArgs e) => WindowState = WindowState.Minimized;

    private void BtnMaximize_Click(object sender, RoutedEventArgs e)
        => WindowState = WindowState == WindowState.Maximized ? WindowState.Normal : WindowState.Maximized;

    private void BtnClose_Click(object sender, RoutedEventArgs e) => Close();

    private async void BtnRetry_Click(object sender, RoutedEventArgs e)
    {
        BtnRetry.Visibility = Visibility.Collapsed;
        LoadingPanel.Visibility = Visibility.Visible;
        LoadingText.Text = "正在重试…";
        await EnsurePlatformAsync();
        if (_platformUp && Browser.CoreWebView2 is not null) Browser.CoreWebView2.Reload();
    }

    private void SetStatus(string text, bool ok)
    {
        StatusText.Text = text;
        StatusText.Foreground = new SolidColorBrush(
            (System.Windows.Media.Color)System.Windows.Media.ColorConverter
                .ConvertFromString(ok ? "#38BDF8" : "#F59E0B"));
        FooterRight.Text = DateTime.Now.ToString("yyyy-MM-dd HH:mm");
    }

    private void RefreshChrome()
    {
        BtnMaximize.Content = WindowState == WindowState.Maximized ? "❐" : "▢";
    }
}
