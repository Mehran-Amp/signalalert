import urllib.request
import re
import json
import urllib.parse

headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Referer': 'https://bonbast.com/',
    'Origin': 'https://bonbast.com',
    'X-Requested-With': 'XMLHttpRequest',
    'Accept': 'application/json, text/javascript, */*; q=0.01',
    'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8'
}

try:
    req = urllib.request.Request('https://bonbast.com', headers=headers)
    with urllib.request.urlopen(req, timeout=6) as res:
        cookie = res.headers.get('Set-Cookie', '')
        html = res.read().decode('utf-8', errors='ignore')

    m = re.search(r'param:\s*["\']([^"\']+)["\']', html)
    if m:
        param_val = m.group(1)
        if cookie:
            headers['Cookie'] = cookie

        post_data = urllib.parse.urlencode({'param': param_val}).encode('utf-8')
        post_req = urllib.request.Request('https://bonbast.com/json', data=post_data, headers=headers)
        with urllib.request.urlopen(post_req, timeout=6) as p_res:
            data = json.loads(p_res.read().decode('utf-8'))
            print('Data keys:', list(data.keys()))
            print('Data preview:', str(data)[:500])
except Exception as e:
    print('Error:', e)
