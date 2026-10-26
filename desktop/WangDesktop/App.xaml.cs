using System.Windows;

namespace WangDesktop;

public partial class App : System.Windows.Application
{
    /// <summary>
    /// 应用入口。负责把未处理异常转成可见提示，避免桌面端「静默退出」。
    /// </summary>
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        DispatcherUnhandledException += (_, args) =>
        {
            System.Windows.MessageBox.Show(
                "程序遇到未处理的问题：\n" + args.Exception.Message,
                "王将军AI工作台", System.Windows.MessageBoxButton.OK, System.Windows.MessageBoxImage.Error);
            args.Handled = true;
        };
    }
}
