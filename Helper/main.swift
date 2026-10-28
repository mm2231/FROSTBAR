// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 mm2231 and FrostBar contributors

import Foundation
import FrostBarCore

// FrostBarHelper
//
// A launchd daemon started on demand through its Mach service. It performs no
// work on its own and writes only when the signed FrostBar app asks it to.
// `--restore` is used by the uninstaller and by developers: it releases any
// override recorded in the journal and exits.

let core = HelperCore()

if CommandLine.arguments.contains("--restore") {
    let finished = DispatchSemaphore(value: 0)
    Task {
        await core.prepareForExit()
        finished.signal()
    }
    finished.wait()
    exit(EXIT_SUCCESS)
}

// Restore a stale journal entry before the listener accepts its first request.
let ready = DispatchSemaphore(value: 0)
Task {
    await core.start()
    ready.signal()
}
ready.wait()

let service = HelperRPCService(core: core)
let delegate = HelperServiceDelegate(service: service)
let listener = NSXPCListener(machServiceName: HelperConstants.machServiceName)
listener.delegate = delegate
listener.resume()

var signalSources: [DispatchSourceSignal] = []
for number in [SIGTERM, SIGINT] {
    signal(number, SIG_IGN)
    let source = DispatchSource.makeSignalSource(signal: number, queue: .global(qos: .userInitiated))
    source.setEventHandler {
        Task {
            await core.prepareForExit()
            exit(EXIT_SUCCESS)
        }
    }
    source.resume()
    signalSources.append(source)
}

dispatchMain()
