// +-------------------------------------------------------------------------
//
//   taskmgr-rs - GNOME 窗口提供器调用者认证判定
//
//   文件:       packaging/linux/gnome-shell-extension/window-provider@org.taskmgr_rs.TaskManager/authorization.js
//
//   日期:       2026年08月22日
//   环境:       Windows 11 x64；Node.js 25.8.1；目标 GNOME Shell 45–51/GJS
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   D-Bus Specification；org.freedesktop.DBus 凭据接口；proc(5)；stat(2)
// --------------------------------------------------------------------------

// 对从 D-Bus 调用上下文取得的唯一发送者进行 fail-closed 判定。
// 调用者必须持续拥有同一总线名称，并执行不可被普通用户替换的系统安装文件。

const ROOT_UID = 0;
const GROUP_OR_OTHER_WRITE_BITS = 0o022;

export class CallerAuthorizationError extends Error {
    constructor(message) {
        super(message);
        this.name = 'CallerAuthorizationError';
    }
}

export async function authorizeCaller({
    sender,
    serviceUid,
    resolveSenderPid,
    inspectTrustedExecutable,
    inspectProcessExecutable,
}) {
    if (typeof sender !== 'string' || !sender.startsWith(':') || sender.length > 255)
        throw new CallerAuthorizationError('the invocation has no unique D-Bus sender');

    const firstPid = await resolveSenderPid(sender);
    assertPid(firstPid);
    assertUid(serviceUid, 'window-provider service');

    const trusted = await inspectTrustedExecutable();
    assertTrustedInstallation(trusted);

    const processBefore = await inspectProcessExecutable(firstPid);
    assertProcessExecutable(processBefore, serviceUid);
    if (processBefore.device !== trusted.file.device ||
        processBefore.inode !== trusted.file.inode) {
        throw new CallerAuthorizationError(
            'the caller is not executing the trusted taskmgr-rs binary',
        );
    }

    // Resolve the unique name again after procfs and filesystem inspection. If
    // the connection vanished, or the numeric PID was reused, the authorization
    // attempt fails before any window metadata is collected.
    const secondPid = await resolveSenderPid(sender);
    assertPid(secondPid);
    if (secondPid !== firstPid) {
        throw new CallerAuthorizationError(
            'the D-Bus sender changed process identity during authorization',
        );
    }

    const processAfter = await inspectProcessExecutable(secondPid);
    assertProcessExecutable(processAfter, serviceUid);
    if (processAfter.startTime !== processBefore.startTime ||
        processAfter.device !== processBefore.device ||
        processAfter.inode !== processBefore.inode) {
        throw new CallerAuthorizationError(
            'the caller process changed identity during authorization',
        );
    }

    return firstPid;
}

function assertProcessExecutable(process, serviceUid) {
    assertRegularFile(process, 'caller executable');
    assertUid(process.processUid, 'caller process');
    if (process.processUid !== serviceUid)
        throw new CallerAuthorizationError('the caller belongs to another user');
    if (typeof process.startTime !== 'string' ||
        !/^[0-9]+$/.test(process.startTime)) {
        throw new CallerAuthorizationError('the caller has no valid procfs start time');
    }
}

function assertTrustedInstallation(trusted) {
    if (!trusted || !Array.isArray(trusted.parentDirectories) || !trusted.file)
        throw new CallerAuthorizationError('trusted installation metadata is incomplete');
    if (trusted.parentDirectories.length === 0)
        throw new CallerAuthorizationError('trusted installation has no verified parent');

    for (const directory of trusted.parentDirectories) {
        if (directory?.kind !== 'directory') {
            throw new CallerAuthorizationError(
                'a trusted executable parent is not a directory',
            );
        }
        assertRootOwnedNonWritable(directory, 'trusted executable parent');
    }

    assertRegularFile(trusted.file, 'trusted executable');
    assertRootOwnedNonWritable(trusted.file, 'trusted executable');
}

function assertRegularFile(file, description) {
    if (!file || file.kind !== 'regular' ||
        typeof file.device !== 'string' || !/^[0-9]+$/.test(file.device) ||
        typeof file.inode !== 'string' || !/^[0-9]+$/.test(file.inode)) {
        throw new CallerAuthorizationError(`${description} has no stable file identity`);
    }
}

function assertRootOwnedNonWritable(file, description) {
    if (!Number.isSafeInteger(file.uid) || file.uid !== ROOT_UID ||
        !Number.isSafeInteger(file.mode) ||
        (file.mode & GROUP_OR_OTHER_WRITE_BITS) !== 0) {
        throw new CallerAuthorizationError(
            `${description} is not root-owned and protected from replacement`,
        );
    }
}

function assertPid(pid) {
    if (!Number.isSafeInteger(pid) || pid <= 0 || pid > 0xffff_ffff)
        throw new CallerAuthorizationError('D-Bus returned an invalid caller PID');
}

function assertUid(uid, description) {
    if (!Number.isSafeInteger(uid) || uid < 0 || uid > 0xffff_ffff)
        throw new CallerAuthorizationError(`${description} has an invalid UID`);
}
