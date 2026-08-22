// +-------------------------------------------------------------------------
//
//   taskmgr-rs - GNOME 窗口提供器调用者认证回归测试
//
//   文件:       packaging/linux/gnome-shell-extension/window-provider@org.taskmgr_rs.TaskManager/authorization.test.mjs
//
//   日期:       2026年08月22日
//   环境:       Windows 11 x64；Node.js 25.8.1
//   作者:       JamesLinYJ
//   协助:       OpenAI Codex:gpt-5.6-sol
//   参考标准:   Node.js test runner；项目 WindowProvider1 调用者认证契约
// --------------------------------------------------------------------------

import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import test from 'node:test';

const moduleSource = await readFile(
    new URL('./authorization.js', import.meta.url),
    'utf8',
);
const {authorizeCaller} = await import(
    `data:text/javascript;base64,${Buffer.from(moduleSource).toString('base64')}`
);

const trustedFile = Object.freeze({
    kind: 'regular',
    uid: 0,
    mode: 0o100755,
    device: '8',
    inode: '4242',
});
const secureDirectory = Object.freeze({
    kind: 'directory',
    uid: 0,
    mode: 0o040755,
    device: '8',
    inode: '1',
});

function dependencies(overrides = {}) {
    return {
        sender: ':1.42',
        serviceUid: 1000,
        resolveSenderPid: async () => 2400,
        inspectTrustedExecutable: async () => ({
            parentDirectories: [secureDirectory, secureDirectory, secureDirectory],
            file: trustedFile,
        }),
        inspectProcessExecutable: async () => ({
            ...trustedFile,
            processUid: 1000,
            startTime: '100000',
        }),
        ...overrides,
    };
}

async function rejectsAuthorization(overrides) {
    await assert.rejects(authorizeCaller(dependencies(overrides)));
}

test('accepts a stable sender executing the protected installed binary', async () => {
    assert.equal(await authorizeCaller(dependencies()), 2400);
});

test('rejects an arbitrary session-bus process with a different executable', async () => {
    await rejectsAuthorization({
        inspectProcessExecutable: async () => ({
            ...trustedFile,
            device: '9',
            processUid: 1000,
            startTime: '100000',
        }),
    });
    await rejectsAuthorization({
        inspectProcessExecutable: async () => ({
            ...trustedFile,
            inode: '9999',
            processUid: 1000,
            startTime: '100000',
        }),
    });
});

test('compares inode identities exactly beyond the JavaScript safe integer range', async () => {
    const highInode = '9007199254740993';
    await rejectsAuthorization({
        inspectTrustedExecutable: async () => ({
            parentDirectories: [secureDirectory],
            file: {...trustedFile, inode: highInode},
        }),
        inspectProcessExecutable: async () => ({
            ...trustedFile,
            inode: '9007199254740992',
            processUid: 1000,
            startTime: '100000',
        }),
    });
});

test('rejects PID reuse and a sender that disappears during inspection', async () => {
    let calls = 0;
    await rejectsAuthorization({
        resolveSenderPid: async () => [2400, 2401][calls++],
    });

    calls = 0;
    await rejectsAuthorization({
        resolveSenderPid: async () => {
            if (calls++ === 0)
                return 2400;
            throw new Error('org.freedesktop.DBus.Error.NameHasNoOwner');
        },
    });
});

test('rejects the same PID when procfs start time or user changes', async () => {
    let inspections = 0;
    await rejectsAuthorization({
        inspectProcessExecutable: async () => ({
            ...trustedFile,
            processUid: 1000,
            startTime: inspections++ === 0 ? '100000' : '100001',
        }),
    });
    await rejectsAuthorization({
        inspectProcessExecutable: async () => ({
            ...trustedFile,
            processUid: 1001,
            startTime: '100000',
        }),
    });
});

test('rejects portable, user-owned, or replaceable installations', async () => {
    await rejectsAuthorization({
        inspectTrustedExecutable: async () => {
            throw new Error('/usr/lib/taskmgr-rs/taskmgr_rs is absent');
        },
    });
    await rejectsAuthorization({
        inspectTrustedExecutable: async () => ({
            parentDirectories: [secureDirectory],
            file: {...trustedFile, uid: 1000},
        }),
    });
    await rejectsAuthorization({
        inspectTrustedExecutable: async () => ({
            parentDirectories: [{...secureDirectory, mode: 0o040777}],
            file: trustedFile,
        }),
    });
});

test('extension obtains the sender from the invocation and gates enumeration', async () => {
    const extension = await readFile(new URL('./extension.js', import.meta.url), 'utf8');

    assert.match(extension, /GetWindowsAsync\(_parameters, invocation\)/);
    assert.match(extension, /GetVersionAsync\(_parameters, invocation\)/);
    assert.match(extension, /const sender = invocation\.get_sender\(\)/);
    assert.match(extension, /await authorizeCaller\(/);
    assert.match(extension, /resolveSenderPid:/);
    assert.match(
        extension,
        /get_attribute_uint32\('unix::device'\)\.toString\(\)/,
    );
    assert.match(
        extension,
        /get_attribute_as_string\('unix::inode'\)/,
    );
    assert.match(
        extension,
        /requireFileAttribute\(info, 'unix::inode', Gio\.FileAttributeType\.UINT64\)/,
    );
    assert.doesNotMatch(extension, /get_attribute_uint64\('unix::device'\)/);
    assert.doesNotMatch(extension, /get_attribute_uint64\('unix::inode'\)/);
    assert.match(extension, /this\._serializeSnapshot\(\)/);
    assert.doesNotMatch(extension, /\n\s+GetVersion\(\)/);
    assert.ok(
        extension.indexOf('await authorizeCaller(') <
            extension.indexOf('invocation.return_value(createReply())'),
        'the reply callback must run only after caller authorization',
    );
    assert.ok(
        extension.indexOf('if (this._disabled || cancellable.is_cancelled())') <
            extension.indexOf('invocation.return_value(createReply())'),
        'disable cancellation must be checked before collecting window metadata',
    );
});
