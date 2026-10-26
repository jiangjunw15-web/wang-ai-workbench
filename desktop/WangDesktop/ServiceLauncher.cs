using System;
using System.Diagnostics;
using System.IO;

namespace WangDesktop;

/// <summary>
/// 本机服务的启动器。
///
/// 安全说明：这里只做一件事 —— 通过 Windows 的文件关联机制打开一个**固定绝对路径**
/// 的启动脚本。没有任何用户输入、配置项或网络数据会进入该路径，也没有命令行参数被
/// 传递，更没有经过 shell 字符串拼接；脚本内部执行的是固定的 WSL / node 命令。
/// </summary>
internal static class ServiceLauncher
{
    /// <summary>候选路径：优先安装目录，其次开发目录。</summary>
    private static readonly string[] Candidates =
    {
        Path.Combine(AppContext.BaseDirectory, "wang-service-start.bat"),
        @"D:\automate\desktop\wang-service-start.bat",
    };

    /// <summary>拉起本机服务（WSL 容器 + 端口中继）。失败时抛出异常由调用方显示。</summary>
    /// <exception cref="FileNotFoundException">启动脚本缺失。</exception>
    public static void Launch()
    {
        var script = Candidates.FirstOrDefault(File.Exists);
        if (script is null)
        {
            throw new FileNotFoundException(
                "找不到服务启动脚本", string.Join(" / ", Candidates));
        }

        // UseShellExecute=true 走 ShellExecuteW，不创建命令行，也无参数可注入。
        Process.Start(new ProcessStartInfo
        {
            FileName = script,
            UseShellExecute = true,
            WindowStyle = ProcessWindowStyle.Hidden,
        });
    }
}
