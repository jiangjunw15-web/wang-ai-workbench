using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Threading;
using Microsoft.Win32;

namespace WangInstaller;

/// <summary>
/// 王将军AI工作台 — 安装器。
///
/// 职责：
///   1. 把桌面端 exe 与图标装到 %LOCALAPPDATA%\Programs\王将军AI工作台
///   2. 创建桌面 / 开始菜单快捷方式
///   3. 写入卸载登记（HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall）
///   4. 设置开机自启（HKCU\...\Run）
///   5. 附带本机服务启动脚本，使桌面端能一键拉起 WSL 里的平台
///
/// 所有路径与注册表键都由程序内部固定或取自系统环境变量，不接受外部输入。
/// </summary>
internal static class Program
{
    private const string AppName = "王将军AI工作台";
    private const string ExeName = "王将军AI工作台.exe";
    private const string UninstallKey = @"Software\Microsoft\Windows\CurrentVersion\Uninstall\WangDesktop";
    private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";

    private static int Main(string[] args)
    {
        Console.OutputEncoding = System.Text.Encoding.UTF8;
        var uninstall = args.Length > 0 && args[0] == "/uninstall";

        try
        {
            return uninstall ? Uninstall() : Install();
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("安装失败：" + ex.Message);
            return 1;
        }
    }

    private static string InstallDir => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "Programs", AppName);

    private static int Install()
    {
        var srcDir = AppContext.BaseDirectory;
        var srcExe = Path.Combine(srcDir, ExeName);
        var installerExe = Environment.ProcessPath;
        if (string.IsNullOrWhiteSpace(installerExe) || !File.Exists(installerExe))
        {
            Console.Error.WriteLine("无法定位当前安装器文件。");
            return 1;
        }
        // 首选同目录载荷；没有则从嵌入资源释放。
        if (!File.Exists(srcExe))
        {
            srcExe = ExtractResource("payload.app.exe", ExeName);
            if (srcExe is null)
            {
                Console.Error.WriteLine("安装包不完整，缺少 王将军AI工作台.exe");
                return 1;
            }
        }

        Console.WriteLine($"正在安装 {AppName} …");
        StopInstalledApp();
        Directory.CreateDirectory(InstallDir);

        var dstExe = Path.Combine(InstallDir, ExeName);
        CopyOver(srcExe, dstExe);

        var dstUninstaller = Path.Combine(InstallDir, "卸载王将军AI工作台.exe");
        if (!string.Equals(Path.GetFullPath(installerExe), Path.GetFullPath(dstUninstaller), StringComparison.OrdinalIgnoreCase))
            CopyOver(installerExe, dstUninstaller);

        var srcIco = Path.Combine(srcDir, "wang.ico");
        if (!File.Exists(srcIco)) srcIco = ExtractResource("payload.icon.ico", "wang.ico");
        if (srcIco is not null) CopyOver(srcIco, Path.Combine(InstallDir, "wang.ico"));

        var srcScript = Path.Combine(srcDir, "wang-service-start.bat");
        if (!File.Exists(srcScript)) srcScript = ExtractResource("payload.service.bat", "wang-service-start.bat");
        if (srcScript is not null)
            CopyOver(srcScript, Path.Combine(InstallDir, "wang-service-start.bat"));

        var srcRelay = Path.Combine(srcDir, "relay.js");
        if (!File.Exists(srcRelay)) srcRelay = ExtractResource("payload.relay.js", "relay.js");
        if (srcRelay is not null)
            CopyOver(srcRelay, Path.Combine(InstallDir, "relay.js"));

        CreateShortcuts(dstExe);
        WriteUninstallInfo(dstExe);
        SetAutoStart(true);

        Console.WriteLine();
        Console.WriteLine("安装完成。");
        Console.WriteLine($"  程序目录：{InstallDir}");
        Console.WriteLine("  桌面 / 开始菜单快捷方式：已创建");
        Console.WriteLine("  开机自启：已开启");
        Console.WriteLine();
        Console.WriteLine("正在启动…");
        TryStart(dstExe);
        return 0;
    }

    /// <summary>把嵌入资源释放到临时文件，返回路径；失败返回 null。</summary>
    private static string? ExtractResource(string logicalName, string fileName)
    {
        try
        {
            var asm = Assembly.GetExecutingAssembly();
            using var stream = asm.GetManifestResourceStream(logicalName);
            if (stream is null) return null;
            var path = Path.Combine(Path.GetTempPath(), fileName);
            using var fs = File.Create(path);
            stream.CopyTo(fs);
            return path;
        }
        catch
        {
            return null;
        }
    }

    private static int Uninstall()
    {
        Console.WriteLine($"正在卸载 {AppName} …");
        try { SetAutoStart(false); } catch { }
        DeleteShortcuts();
        try { RegistryDelete(UninstallKey); } catch { }

        // WebView2 / desktop process may still hold files. Schedule a detached
        // cleanup script, then exit this uninstaller so deletion can succeed.
        var current = Environment.ProcessPath;
        var cleanup = Path.Combine(Path.GetTempPath(), "wang-uninstall-" + Guid.NewGuid().ToString("N") + ".cmd");
        var lines = new[]
        {
            "@echo off",
            "timeout /t 2 /nobreak >nul",
            "taskkill /f /im \"王将军AI工作台.exe\" >nul 2>&1",
            "rmdir /s /q \"" + InstallDir + "\" >nul 2>&1",
            "reg delete \"HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\WangDesktop\" /f >nul 2>&1",
            "del /f /q \"%~f0\" >nul 2>&1",
        };
        File.WriteAllLines(cleanup, lines, System.Text.Encoding.Default);
        Process.Start(new ProcessStartInfo(cleanup) { UseShellExecute = true, WindowStyle = ProcessWindowStyle.Hidden });
        Console.WriteLine("卸载任务已安排，安装目录将在程序退出后清理。");
        return 0;
    }

    private static void StopInstalledApp()
    {
        try
        {
            var processName = Path.GetFileNameWithoutExtension(ExeName);
            foreach (var p in Process.GetProcessesByName(processName))
            {
                try { p.CloseMainWindow(); } catch { }
                try { if (!p.WaitForExit(2500)) p.Kill(true); } catch { }
                p.Dispose();
            }
        }
        catch { }
    }

    private static void CopyOver(string src, string dst)
    {
        if (File.Exists(dst))
        {
            try { File.Delete(dst); } catch { /* 被占用时直接覆盖 */ }
        }
        File.Copy(src, dst, true);
    }

    private static void CreateShortcuts(string exe)
    {
        var desktop = Environment.GetFolderPath(Environment.SpecialFolder.Desktop);
        var startMenu = Environment.GetFolderPath(Environment.SpecialFolder.CommonPrograms);
        var startMenuUser = Environment.GetFolderPath(Environment.SpecialFolder.Programs);

        void Link(string dir, string name)
        {
            var path = Path.Combine(dir, name + ".lnk");
            try
            {
                var shellType = Type.GetTypeFromProgID("WScript.Shell");
                if (shellType is null) throw new InvalidOperationException("WScript.Shell 不可用");
                var shell = Activator.CreateInstance(shellType)
                    ?? throw new InvalidOperationException("无法创建 WScript.Shell");
                var shortcut = shellType.InvokeMember("CreateShortcut", System.Reflection.BindingFlags.InvokeMethod,
                    null, shell, new object[] { path })
                    ?? throw new InvalidOperationException("无法创建快捷方式对象");
                var shortcutType = shortcut.GetType();
                shortcutType.InvokeMember("TargetPath", System.Reflection.BindingFlags.SetProperty,
                    null, shortcut, new object[] { exe });
                shortcutType.InvokeMember("WorkingDirectory", System.Reflection.BindingFlags.SetProperty,
                    null, shortcut, new object[] { Path.GetDirectoryName(exe)! });
                shortcutType.InvokeMember("IconLocation", System.Reflection.BindingFlags.SetProperty,
                    null, shortcut, new object[] { exe + ",0" });
                shortcutType.InvokeMember("Description", System.Reflection.BindingFlags.SetProperty,
                    null, shortcut, new object[] { AppName });
                shortcutType.InvokeMember("Save", System.Reflection.BindingFlags.InvokeMethod,
                    null, shortcut, Array.Empty<object>());
            }
            catch (Exception ex)
            {
                Console.WriteLine($"快捷方式创建失败（{dir}）：{ex.Message}");
            }
        }

        Link(desktop, AppName);
        Link(startMenu, AppName);
        Link(startMenuUser, AppName);
    }

    private static void DeleteShortcuts()
    {
        foreach (var dir in new[]
        {
            Environment.GetFolderPath(Environment.SpecialFolder.Desktop),
            Environment.GetFolderPath(Environment.SpecialFolder.CommonPrograms),
            Environment.GetFolderPath(Environment.SpecialFolder.Programs),
        })
        {
            var p = Path.Combine(dir, AppName + ".lnk");
            try { if (File.Exists(p)) File.Delete(p); } catch { }
        }
    }

    private static void WriteUninstallInfo(string exe)
    {
        using var k = Registry.CurrentUser.CreateSubKey(UninstallKey);
        k.SetValue("DisplayName", AppName);
        k.SetValue("DisplayIcon", exe);
        k.SetValue("InstallLocation", InstallDir);
        k.SetValue("Publisher", "王将军");
        k.SetValue("DisplayVersion", "1.0.0");
        k.SetValue("NoModify", 1);
        k.SetValue("NoRepair", 1);
        k.SetValue("UninstallString", $"\"{Path.Combine(InstallDir, "卸载王将军AI工作台.exe")}\" /uninstall");
        k.SetValue("InstallDate", DateTime.Now.ToString("yyyyMMdd"));
    }

    private static void SetAutoStart(bool enable)
    {
        using var k = Registry.CurrentUser.CreateSubKey(RunKey);
        if (enable)
        {
            var exe = Path.Combine(InstallDir, ExeName);
            k.SetValue("WangDesktop", "\"" + exe + "\"");
        }
        else if (k.GetValue("WangDesktop") is not null)
        {
            k.DeleteValue("WangDesktop");
        }
    }

    private static void RegistryDelete(string path)
    {
        Registry.CurrentUser.DeleteSubKeyTree(path, false);
    }

    private static void TryStart(string exe)
    {
        try
        {
            var psi = new ProcessStartInfo(exe) { UseShellExecute = true };
            Process.Start(psi);
        }
        catch (Exception ex)
        {
            Console.WriteLine("自动启动失败，请手动运行：" + ex.Message);
        }
    }
}
