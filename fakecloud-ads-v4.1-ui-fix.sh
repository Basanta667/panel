#!/usr/bin/env bash
set -euo pipefail

PANEL="/var/www/pterodactyl"
DEV="$PANEL/.blueprint/dev"
VIEW="$DEV/admin/view.blade.php"
STAMP="$(date +%Y%m%d-%H%M%S)"

if [ ! -f "$VIEW" ]; then
  echo "ERROR: $VIEW not found"
  exit 1
fi

cp "$VIEW" "$VIEW.bak-$STAMP"

echo "[1/4] Backup created: $VIEW.bak-$STAMP"

python3 - <<'PY'
from pathlib import Path
p = Path('/var/www/pterodactyl/.blueprint/dev/admin/view.blade.php')
s = p.read_text()

# Force the content editor to be clearly visible in themes such as Arix.
s = s.replace(
    '.fc-a button{margin-right:4px;margin-bottom:4px}',
    '.fc-a button{margin-right:4px;margin-bottom:4px}#adContent{display:block!important;width:100%!important;min-height:180px!important;height:180px!important;resize:vertical!important;background:#2f304f!important;color:#fff!important;border:1px solid #555a86!important;border-radius:6px!important;padding:10px!important;opacity:1!important;visibility:visible!important}'
)

# English-only interface text.
repls = {
    'Visible only • Close button • Image + HTML • Random show chance':
        'Visible ads only • Close button • Image and HTML ads • Random display chance',
    'Image URL ya HTML Code use karo. Show Chance se ad har page load par zaroori nahi dikhega.':
        'Choose Image URL or HTML Code. Display Chance controls how often this ad is eligible to appear.',
    'Image URL paste karo.': 'Paste the banner image URL here.',
    'Custom HTML/CSS snippet paste karo.': 'Paste your custom HTML/CSS code in the box above.',
    '100 = always eligible, 70 = about 70%, 30 = rare.':
        '100 = always eligible, 70 = shown about 70% of the time, 30 = shown less often.',
    'AdSense approval ke baad dedicated Publisher/Slot IDs use karo. AdSense code ko Custom HTML me mat daalo.':
        'After AdSense approval, use the dedicated Publisher ID and Slot ID fields. Do not paste AdSense code into Custom HTML ads.',
    'Har line me ek email.': 'Enter one email address per line. These users will not see ads.',
    'At least 1 location select karo': 'Select at least one ad location',
}
for a,b in repls.items():
    s=s.replace(a,b)

# Better labels / placeholders.
s=s.replace('<label id="contentLabel">Banner Image URL</label><textarea id="adContent" class="form-control" rows="5" placeholder="https://example.com/banner.png"></textarea><div id="contentHelp" class="fc-m">Paste the banner image URL here.</div>',
'''<label id="contentLabel">Banner Image URL</label>
<textarea id="adContent" class="form-control" rows="8" spellcheck="false" placeholder="https://example.com/banner.png"></textarea>
<div id="contentHelp" class="fc-m">Paste the banner image URL in the box above.</div>''')

# If exact compact markup was not found, make textarea taller anyway.
s=s.replace('id="adContent" class="form-control" rows="5"', 'id="adContent" class="form-control" rows="8" spellcheck="false"')

# English dynamic mode text and a much clearer HTML placeholder.
s=s.replace(
    "E('adContent').placeholder=z?'<div style=\"padding:15px\">Your ad HTML here</div>':'https://example.com/banner.png';E('contentHelp').textContent=z?'Paste your custom HTML/CSS code in the box above.':'Paste the banner image URL here.'",
    "E('adContent').placeholder=z?'<div style=\"padding:16px;background:#111827;color:#fff\">Your advertisement HTML here</div>':'https://example.com/banner.png';E('contentHelp').textContent=z?'Paste your custom HTML/CSS code in the box above.':'Paste the banner image URL in the box above.'"
)

p.write_text(s)
PY

echo "[2/4] UI text translated to English and HTML editor made visible."

grep -q 'id="adContent"' "$VIEW" || { echo "ERROR: adContent editor not found"; exit 1; }

cd "$PANEL"
blueprint -build
php artisan view:clear
php artisan optimize:clear

echo "[3/4] Blueprint rebuilt and caches cleared."

echo
echo "[4/4] Done"
echo "Open: /admin/extensions/fakecloudadsmanager"
echo "Hard refresh: Ctrl + Shift + R"
echo "For HTML ads: Type = HTML Code, then paste code into the large HTML Code box above Click URL."
