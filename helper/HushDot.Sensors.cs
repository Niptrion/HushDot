// HushDot.Sensors - camera activity helper for HushDot (MIT License).
//
// Listens to the Windows sensor activity monitor (Media Foundation,
// MFCreateSensorActivityMonitor) and tells HushDot which processes are streaming from a
// camera. AutoHotkey cannot receive these reports itself, because Windows delivers them on
// worker threads.
//
// It never opens a camera, has no network access and writes no files. It sends a WM_COPYDATA
// message ("CAM|app1.exe,app2.exe") to the HushDot window whenever the list changes, and exits
// when that window is gone.
//
// Usage: HushDot.Sensors.exe <HushDot window handle, decimal>
// Build: helper\build-helper.cmd (uses the C# compiler included with Windows)
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

[assembly: AssemblyTitle("HushDot.Sensors")]
[assembly: AssemblyDescription("HushDot camera activity helper")]
[assembly: AssemblyProduct("HushDot")]
[assembly: AssemblyCopyright("HushDot fork - MIT License")]
[assembly: AssemblyVersion("2.0.0.0")]
[assembly: AssemblyFileVersion("2.0.0.0")]

static class Program
{
    [ComImport, Guid("de5072ee-dbe3-46dc-8a87-b6f631194751"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IMFSensorActivitiesReportCallback
    {
        [PreserveSig] int OnActivitiesReport(IMFSensorActivitiesReport report);
    }

    [ComImport, Guid("d0cef145-b3f4-4340-a2e5-7a5080ca05cb"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IMFSensorActivityMonitor
    {
        [PreserveSig] int Start();
        [PreserveSig] int Stop();
    }

    [ComImport, Guid("683f7a5e-4a19-43cd-b1a9-dbf4ab3f7777"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IMFSensorActivitiesReport
    {
        [PreserveSig] int GetCount(out uint count);
        [PreserveSig] int GetActivityReport(uint index, out IMFSensorActivityReport report);
        [PreserveSig] int GetActivityReportByDeviceName([MarshalAs(UnmanagedType.LPWStr)] string name, out IMFSensorActivityReport report);
    }

    [ComImport, Guid("3e8c4be1-a8c2-4528-90de-2851bde5fead"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IMFSensorActivityReport
    {
        [PreserveSig] int GetFriendlyName([MarshalAs(UnmanagedType.LPWStr)] StringBuilder name, uint cch, out uint written);
        [PreserveSig] int GetSymbolicLink([MarshalAs(UnmanagedType.LPWStr)] StringBuilder link, uint cch, out uint written);
        [PreserveSig] int GetProcessCount(out uint count);
        [PreserveSig] int GetProcessActivity(uint index, out IMFSensorProcessActivity activity);
    }

    [ComImport, Guid("39dc7f4a-b141-4719-813c-a7f46162a2b8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IMFSensorProcessActivity
    {
        [PreserveSig] int GetProcessId(out uint pid);
        [PreserveSig] int GetStreamingState([MarshalAs(UnmanagedType.Bool)] out bool streaming);
        [PreserveSig] int GetStreamingMode(out int mode);
        [PreserveSig] int GetReportTime(out long fileTime);
    }

    [StructLayout(LayoutKind.Sequential)]
    struct COPYDATASTRUCT { public IntPtr dwData; public int cbData; public IntPtr lpData; }

    [DllImport("mfplat.dll")] static extern int MFStartup(uint version, uint flags);
    [DllImport("mfplat.dll")] static extern int MFShutdown();
    [DllImport("mfsensorgroup.dll")]
    static extern int MFCreateSensorActivityMonitor(IMFSensorActivitiesReportCallback callback, out IMFSensorActivityMonitor monitor);
    [DllImport("user32.dll")] static extern bool IsWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint msg, IntPtr wParam, ref COPYDATASTRUCT lParam,
                                            uint flags, uint timeoutMs, out IntPtr result);

    const uint MF_VERSION = 0x00020070;
    const uint WM_COPYDATA = 0x004A;
    const uint SMTO_ABORTIFHUNG = 0x0002;
    static readonly IntPtr Signature = (IntPtr)0x544D;   // "TM": identifies messages from this helper

    static IntPtr target;
    static readonly object gate = new object();
    static string pending = "CAM|";   // latest state reported by Windows
    static string delivered = null;   // latest state HushDot accepted

    sealed class Callback : IMFSensorActivitiesReportCallback
    {
        public int OnActivitiesReport(IMFSensorActivitiesReport report)
        {
            try
            {
                var names = new SortedSet<string>(StringComparer.OrdinalIgnoreCase);
                uint devices;
                if (report != null && report.GetCount(out devices) == 0)
                {
                    for (uint i = 0; i < devices; i++)
                    {
                        IMFSensorActivityReport device;
                        uint processes;
                        if (report.GetActivityReport(i, out device) != 0 || device == null) continue;
                        if (device.GetProcessCount(out processes) != 0) continue;
                        for (uint p = 0; p < processes; p++)
                        {
                            IMFSensorProcessActivity activity;
                            bool streaming;
                            uint pid;
                            if (device.GetProcessActivity(p, out activity) != 0 || activity == null) continue;
                            if (activity.GetStreamingState(out streaming) != 0 || !streaming) continue;
                            if (activity.GetProcessId(out pid) != 0) continue;
                            names.Add(ProcessName(pid));
                        }
                    }
                }
                lock (gate) pending = "CAM|" + string.Join(",", names);
                Deliver();
            }
            catch { }
            return 0;
        }
    }

    static string ProcessName(uint pid)
    {
        try { return Process.GetProcessById((int)pid).ProcessName + ".exe"; }
        catch { return "PID " + pid; }
    }

    // Sends the latest state if HushDot has not accepted it yet. Called from the callback and
    // every second from Main, so a message missed while HushDot was busy is sent again.
    static void Deliver()
    {
        lock (gate)
        {
            if (pending == delivered) return;
            byte[] bytes = Encoding.Unicode.GetBytes(pending + "\0");
            IntPtr memory = Marshal.AllocHGlobal(bytes.Length);
            try
            {
                Marshal.Copy(bytes, 0, memory, bytes.Length);
                var data = new COPYDATASTRUCT { dwData = Signature, cbData = bytes.Length, lpData = memory };
                IntPtr result;
                if (SendMessageTimeout(target, WM_COPYDATA, IntPtr.Zero, ref data, SMTO_ABORTIFHUNG, 3000, out result) != IntPtr.Zero
                    && result != IntPtr.Zero)
                    delivered = pending;
            }
            finally { Marshal.FreeHGlobal(memory); }
        }
    }

    [MTAThread]
    static int Main(string[] args)
    {
        // Windows "N" editions without the Media Feature Pack lack mfplat.dll, and old Windows 10
        // builds lack MFCreateSensorActivityMonitor: exit quietly instead of crashing, and
        // HushDot falls back to the Windows privacy records.
        try { return Run(args); }
        catch { return 5; }
    }

    static int Run(string[] args)
    {
        long handle;
        if (args.Length < 1 || !long.TryParse(args[0], out handle) || !IsWindow((IntPtr)handle))
            return 2;
        target = (IntPtr)handle;

        if (MFStartup(MF_VERSION, 0) != 0)
            return 3;
        var callback = new Callback();
        IMFSensorActivityMonitor monitor;
        if (MFCreateSensorActivityMonitor(callback, out monitor) != 0 || monitor == null || monitor.Start() != 0)
        {
            MFShutdown();
            return 4;
        }
        Deliver();   // tells HushDot the helper is running, even before the first report

        while (IsWindow(target))
        {
            Thread.Sleep(1000);
            Deliver();
        }

        monitor.Stop();
        MFShutdown();
        GC.KeepAlive(callback);
        return 0;
    }
}
