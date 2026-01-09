import json
import random
import string
import time
from pathlib import Path
from datetime import datetime

import httpx


def _rand_suffix(length: int = 6) -> str:
    alphabet = string.ascii_lowercase + string.digits
    return ''.join(random.choice(alphabet) for _ in range(length))


def _render_template(value: str, context: dict) -> str:
    # Очень простая подстановка {{var}}
    out = value
    for k, v in context.items():
        out = out.replace(f"{{{{{k}}}}}", str(v))
    return out


def load_spec(spec_path: Path) -> dict:
    with spec_path.open('r', encoding='utf-8') as f:
        return json.load(f)


def run_tests(spec: dict) -> int:
    # Путь к логу и обнуление
    log_path = Path(__file__).with_name('test_log.json')
    results: list[dict] = []
    log_path.write_text(json.dumps({"executed_at": datetime.utcnow().isoformat() + "Z", "results": []}, ensure_ascii=False, indent=2), encoding='utf-8')

    # Новый упрощённый формат
    base_url = spec.get('base_url') or spec.get('meta', {}).get('base_url', 'http://127.0.0.1:8001')
    default_headers = spec.get('headers', {}).copy()

    # Поддержка старого формата заголовков
    meta = spec.get('meta', {})
    if meta.get('api_key') and 'X-API-Key' not in default_headers:
        default_headers['X-API-Key'] = meta['api_key']
    if meta.get('bearer_token') and 'Authorization' not in default_headers:
        default_headers['Authorization'] = f"Bearer {meta['bearer_token']}"

    # Старые поля для совместимости
    params_by_name = spec.get('params_by_name', {})
    params_by_path = spec.get('params_by_path', {})
    sections_legacy = spec.get('sections', [])

    # Новый список эндпоинтов
    endpoints = spec.get('endpoints', [])

    total = 0
    passed = 0
    tested_keys = set()  # (method, path)

    def _log(method: str, path: str, status_code: int, ok: bool):
        results.append({
            "method": method,
            "path": path,
            "status_code": status_code,
            "ok": ok
        })

    with httpx.Client(base_url=base_url, timeout=15.0, headers=default_headers) as client:
        global_ctx = {}

        # Новый упрощённый проход
        for ep in endpoints:
            total += 1
            method = (ep.get('method') or 'GET').upper()
            path = ep.get('path')
            params = ep.get('params') or {}
            data_json = ep.get('json')

            if not path:
                print(f"SKIP: empty path in endpoints entry")
                total -= 1
                continue

            try:
                if method == 'GET':
                    resp = client.get(path, params=params)
                elif method == 'POST':
                    resp = client.post(path, params=params, json=data_json)
                elif method == 'PUT':
                    resp = client.put(path, params=params, json=data_json)
                elif method == 'DELETE':
                    resp = client.delete(path, params=params, json=data_json)
                else:
                    raise ValueError(f"Unsupported method: {method}")

                ok = 200 <= resp.status_code < 300
                if ok:
                    try:
                        payload = resp.json()
                        if isinstance(payload, dict) and 'access_token' in payload:
                            global_ctx['access_token'] = payload['access_token']
                    except Exception:
                        pass

                status = 'OK' if ok else f"FAIL({resp.status_code})"
                print(f"{method} {path} -> {status}")
                if not ok:
                    try:
                        print(f"Body: {resp.text[:500]}")
                    except Exception:
                        pass
                _log(method, path, resp.status_code, ok)
                passed += 1 if ok else 0
                tested_keys.add((method, path))
            except Exception as e:
                print(f"{method} {path} -> EXC: {e}")
                _log(method, path, 0, False)

        # Старый формат (sections) — поддерживаем для совместимости
        for section in sections_legacy:
            name = section.get('name', 'unnamed')
            print(f"\n=== SECTION(legacy): {name} ===")

            sec_vars = section.get('variables', {}).copy()
            if 'email_prefix' in sec_vars:
                sec_vars['email'] = f"{sec_vars['email_prefix']}_{_rand_suffix()}@example.com"
            if 'username_prefix' in sec_vars:
                sec_vars['username'] = f"{sec_vars['username_prefix']}_{_rand_suffix()}"

            for ep in section.get('endpoints', []):
                total += 1
                method = ep.get('method', 'GET').upper()
                path = ep.get('path')
                data_json = ep.get('json')

                if isinstance(path, str):
                    path = _render_template(path, {**global_ctx, **sec_vars})
                if isinstance(data_json, dict):
                    rendered = json.loads(json.dumps(data_json))
                    for k, v in list(rendered.items()):
                        if isinstance(v, str):
                            rendered[k] = _render_template(v, {**global_ctx, **sec_vars})
                    data_json = rendered

                url = path
                try:
                    query_params = params_by_path.get(path, {}) if isinstance(path, str) else {}
                    if method == 'GET':
                        resp = client.get(url, params=query_params)
                    elif method == 'POST':
                        resp = client.post(url, params=query_params, json=data_json)
                    elif method == 'PUT':
                        resp = client.put(url, params=query_params, json=data_json)
                    elif method == 'DELETE':
                        resp = client.delete(url, params=query_params, json=data_json)
                    else:
                        raise ValueError(f"Unsupported method: {method}")

                    ok = 200 <= resp.status_code < 300
                    if ok:
                        try:
                            payload = resp.json()
                            if isinstance(payload, dict) and 'access_token' in payload:
                                global_ctx['access_token'] = payload['access_token']
                        except Exception:
                            pass

                    status = 'OK' if ok else f"FAIL({resp.status_code})"
                    print(f"{method} {url} -> {status}")
                    if not ok:
                        try:
                            print(f"Body: {resp.text[:500]}")
                        except Exception:
                            pass
                    _log(method, url, resp.status_code, ok)
                    passed += 1 if ok else 0
                    tested_keys.add((method, url))
                except Exception as e:
                    print(f"{method} {url} -> EXC: {e}")
                    _log(method, url, 0, False)

        # Авто-тест GET эндпоинтов без path-параметров
        try:
            routes = client.get('/_debug/routes').json()
            print("\n=== SECTION: autodiscovered(GET) ===")
            for r in routes:
                methods = set(r.get('methods') or [])
                path = r.get('path')
                if not path or 'GET' not in methods:
                    continue
                if '{' in path or '}' in path:
                    continue
                key = ('GET', path)
                if key in tested_keys:
                    continue
                total += 1
                try:
                    # Параметры: приоритет у нового формата (endpoints), иначе старые карты
                    q = {}
                    for ep in endpoints:
                        if ep.get('method', 'GET').upper() == 'GET' and ep.get('path') == path:
                            q = ep.get('params') or {}
                            break
                    if not q:
                        name = r.get('name') or ''
                        q = params_by_name.get(name) or params_by_path.get(path) or {}
                    resp = client.get(path, params=q)
                    if 200 <= resp.status_code < 300:
                        print(f"GET {path} -> OK")
                        _log('GET', path, resp.status_code, True)
                        passed += 1
                    elif resp.status_code == 422:
                        print(f"GET {path} -> SKIP(422)")
                        total -= 1
                    else:
                        print(f"GET {path} -> FAIL({resp.status_code})")
                        _log('GET', path, resp.status_code, False)
                        try:
                            print(f"Body: {resp.text[:500]}")
                        except Exception:
                            pass
                except Exception as e:
                    print(f"GET {path} -> EXC: {e}")
                    _log('GET', path, 0, False)
        except Exception as e:
            print(f"Autodiscover failed: {e}")

    # Финальная запись лога
    sorted_results = sorted(results, key=lambda r: (r.get("ok", True),))
    log_path.write_text(json.dumps({
        "executed_at": datetime.utcnow().isoformat() + "Z",
        "results": sorted_results
    }, ensure_ascii=False, indent=2), encoding='utf-8')

    print(f"\n=== SUMMARY: passed {passed}/{total} ===")
    return 0 if passed == total else 1


if __name__ == '__main__':
    spec_path = Path(__file__).with_name('test_all_api_json.json')
    spec = load_spec(spec_path)
    exit_code = run_tests(spec)
    raise SystemExit(exit_code)


