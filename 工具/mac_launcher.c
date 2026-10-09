#include <mach-o/dyld.h>
#include <sys/stat.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <limits.h>

int main(void) {
    char executable[PATH_MAX], resolved[PATH_MAX], contents[PATH_MAX];
    uint32_t length = sizeof(executable);
    if (_NSGetExecutablePath(executable, &length) != 0 || !realpath(executable, resolved)) return 1;
    char *slash = strrchr(resolved, '/');
    if (!slash) return 1;
    *slash = '\0';
    slash = strrchr(resolved, '/');
    if (!slash) return 1;
    *slash = '\0';
    snprintf(contents, sizeof(contents), "%s", resolved);
    char package[PATH_MAX], temporary[PATH_MAX], engine[PATH_MAX], pack[PATH_MAX], log[PATH_MAX];
    snprintf(package, sizeof(package), "%s/../..", contents);
    if (chdir(package) != 0) return 2;
    mkdir("运行数据", 0755);
    mkdir("运行数据/临时", 0755);
    if (!getcwd(package, sizeof(package))) return 2;
    snprintf(temporary, sizeof(temporary), "%s/运行数据/临时", package);
    snprintf(log, sizeof(log), "%s/运行数据/游玩.log", package);
    snprintf(engine, sizeof(engine), "%s/Resources/Godot", contents);
    snprintf(pack, sizeof(pack), "%s/Resources/裳泓村.pck", contents);
    unsetenv("HOME");
    setenv("TMPDIR", temporary, 1);
    setenv("__GODOT_SHELL_ENV_SET", "1", 1);
    freopen(log, "a", stderr);
    char *args[] = { engine, "--main-pack", pack, "--log-file", log, NULL };
    execv(engine, args);
    perror("裳泓村启动失败");
    return 3;
}
