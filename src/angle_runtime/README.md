Windows ANGLE runtime payload used by the packed executable path.

Files in this directory are embedded into `asteroids.exe` with `@embedFile`,
then extracted to `%LOCALAPPDATA%\asteroids\angle-runtime` and preloaded before
raylib initializes GLFW/EGL.

Current source on this machine:
- `C:\Program Files\Joplin`

If you replace these DLLs, keep the same filenames:
- `libEGL.dll`
- `libGLESv2.dll`
- `d3dcompiler_47.dll`
