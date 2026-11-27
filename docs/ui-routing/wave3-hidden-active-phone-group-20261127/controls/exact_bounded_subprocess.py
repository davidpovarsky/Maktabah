def run(name, argv, timeout=120, env=None):
    if free() < FLOOR + 4 * 1024 * 1024 or allocated() >= CAP:
        raise RuntimeError('Owned budget/floor before ' + name)
    step = {'name': name, 'argv': [str(x) for x in argv], 'startAttempted': False,
            'freeBefore': free(), 'allocatedBefore': allocated(),
            'started': datetime.datetime.now(datetime.timezone.utc).isoformat()}
    result['steps'].append(step)
    save()
    process = None
    try:
        with (attempt / (name + '.stdout')).open('wb') as stdout, (attempt / (name + '.stderr')).open('wb') as stderr:
            step['startAttempted'] = True
            save()
            process = subprocess.Popen(step['argv'], stdout=stdout, stderr=stderr,
                                       start_new_session=True, env=env)
            owner = proc_identity(process.pid)
            step['owner'] = owner
            save()
            until = time.monotonic() + timeout
            while process.poll() is None:
                cause = ('timeout' if time.monotonic() >= until else
                         'rootfs_floor' if free() < FLOOR else
                         'owned_cap' if allocated() >= CAP else None)
                if cause:
                    step['interruption'] = cause
                    live = proc_identity(process.pid)
                    if owner is None or live != owner or live['group'] != process.pid:
                        step['cleanup'] = 'UNCERTAIN_OWNERSHIP_NO_SIGNAL'
                        save()
                        raise RuntimeError('Cannot prove exact live process group')
                    os.killpg(process.pid, signal.SIGTERM)
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        if proc_identity(process.pid) != owner:
                            step['cleanup'] = 'UNCERTAIN_OWNERSHIP_NO_ESCALATION'
                            save()
                            raise RuntimeError('Cannot prove escalation owner')
                        os.killpg(process.pid, signal.SIGKILL)
                        process.wait(timeout=5)
                    step['cleanup'] = 'EXACT_OWNED_GROUP_STOPPED_AND_REAPED'
                    break
                time.sleep(0.2)
            step['exit'] = process.wait()
    finally:
        if process is not None and process.poll() is None:
            live = proc_identity(process.pid)
            if live is not None and live == step.get('owner') and live['group'] == process.pid:
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    if proc_identity(process.pid) == step.get('owner'):
                        os.killpg(process.pid, signal.SIGKILL)
                        process.wait(timeout=5)
                    else:
                        step['cleanup'] = 'UNCERTAIN_OWNERSHIP_NO_ESCALATION'
            else:
                step['cleanup'] = 'UNCERTAIN_OWNERSHIP_NO_SIGNAL'
        step['finished'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        step['freeAfter'], step['allocatedAfter'] = free(), allocated()
        step['logs'] = {suffix: pin(attempt / (name + '.' + suffix)) for suffix in ['stdout', 'stderr']
                        if (attempt / (name + '.' + suffix)).exists()}
        save()
    if step.get('exit') != 0:
        raise RuntimeError(name + ' exited ' + str(step.get('exit')))
