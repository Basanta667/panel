#!/usr/bin/env bash
set -euo pipefail
PANEL="/var/www/pterodactyl"
DEV="$PANEL/.blueprint/dev"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="/root/fakecloud-ads-v4-backup-$STAMP"

[ -d "$DEV" ] || { echo "ERROR: $DEV not found"; exit 1; }
mkdir -p "$BACKUP"
cp -a "$DEV/admin/view.blade.php" "$BACKUP/" 2>/dev/null || true
cp -a "$DEV/app/AdsController.php" "$BACKUP/" 2>/dev/null || true
cp -a "$DEV/dashboard/wrapper.blade.php" "$BACKUP/" 2>/dev/null || true

echo "[1/4] Backup: $BACKUP"

cat > "$DEV/app/AdsController.php" <<'PHP'
<?php
namespace Pterodactyl\BlueprintFramework\Extensions\fakecloudadsmanager;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Pterodactyl\Http\Controllers\Controller;

class AdsController extends Controller
{
    private function setting(string $key, string $default = ''): string
    {
        $value = DB::table('settings')->where('key', 'fakecloudadsmanager::' . $key)->value('value');
        return $value === null ? $default : (string) $value;
    }

    public function config(Request $request): JsonResponse
    {
        $enabled = strtolower($this->setting('enabled', '1'));
        if (!in_array($enabled, ['1','true','yes','enabled'], true)) {
            return response()->json(['enabled' => false]);
        }

        $excludedRaw = $this->setting('excluded_users', $this->setting('premium_emails', ''));
        $excluded = preg_split('/[\r\n,]+/', strtolower($excludedRaw), -1, PREG_SPLIT_NO_EMPTY);
        $excluded = array_map('trim', $excluded ?: []);
        $user = $request->user();
        if ($user && in_array(strtolower((string) $user->email), $excluded, true)) {
            return response()->json(['enabled' => false, 'premium' => true]);
        }

        $allowed = ['dashboard','sidebar','console','files','databases','schedules','backups','network','startup','settings','account','footer'];
        $placement = strtolower((string) $request->query('placement', 'dashboard'));
        if (!in_array($placement, $allowed, true)) $placement = 'dashboard';

        $decoded = json_decode($this->setting('ads_json', '[]'), true);
        $stored = is_array($decoded) ? $decoded : [];
        $now = time();
        $ads = [];

        foreach ($stored as $ad) {
            if (!is_array($ad) || ($ad['status'] ?? 'active') !== 'active') continue;
            $locations = isset($ad['locations']) && is_array($ad['locations']) ? $ad['locations'] : ['dashboard'];
            if (!in_array($placement, $locations, true)) continue;

            $start = trim((string) ($ad['start_at'] ?? ''));
            $end = trim((string) ($ad['end_at'] ?? ''));
            if ($start !== '' && strtotime($start) > $now) continue;
            if ($end !== '' && strtotime($end) < $now) continue;

            $content = trim((string) ($ad['content'] ?? ''));
            if ($content === '') continue;

            $type = strtolower((string) ($ad['type'] ?? 'image'));
            if (!in_array($type, ['image','html'], true)) $type = 'image';
            $chance = max(0, min(100, (int) ($ad['show_chance'] ?? 100)));

            $ads[] = [
                'id' => (string) ($ad['id'] ?? ''),
                'name' => (string) ($ad['name'] ?? 'Advertisement'),
                'type' => $type,
                'priority' => (int) ($ad['priority'] ?? 5),
                'show_chance' => $chance,
                'content' => $content,
                'click_url' => (string) ($ad['click_url'] ?? ''),
            ];
        }

        usort($ads, fn($a,$b) => (int)($b['priority'] ?? 0) <=> (int)($a['priority'] ?? 0));
        return response()->json([
            'enabled' => count($ads) > 0,
            'placement' => $placement,
            'rotation_seconds' => max(3, (int) $this->setting('rotation_seconds', '7')),
            'ads' => $ads,
        ]);
    }
}
PHP

echo "[2/4] API updated"

cat > "$DEV/admin/view.blade.php" <<'BLADE'
<style>
.fc-h{position:sticky;top:0;z-index:40;background:#08082b;border:1px solid #4936c9;border-radius:8px;padding:12px 14px;margin-bottom:16px;display:flex;justify-content:space-between;align-items:center}.fc-s{background:#08082b;border:1px solid rgba(95,65,220,.65);border-radius:8px;padding:16px;margin-bottom:18px}.fc-g{display:grid;grid-template-columns:1fr 1fr;gap:14px}.fc-l label{display:inline-block;margin:5px 14px 5px 0;font-weight:400}.fc-m{opacity:.72;font-size:12px}.fc-a button{margin-right:4px;margin-bottom:4px}@media(max-width:800px){.fc-g{grid-template-columns:1fr}}
</style>
<form method="POST" action="" id="fcForm">
{{ csrf_field() }}<input type="hidden" name="_method" value="PATCH"><textarea name="ads_json" id="ads_json" style="display:none;">{{ $ads_json }}</textarea>
<div class="fc-h"><div><b style="font-size:19px"><i class="fa fa-bullhorn"></i> FakeCloud Ads Manager</b><div class="fc-m">Visible only • Close button • Image + HTML • Random show chance</div></div><button class="btn btn-primary" type="submit"><i class="fa fa-save"></i> Save Changes</button></div>

<div class="fc-s"><h3>Global Settings</h3><div class="fc-g"><div class="form-group"><label>Ads Status</label><select class="form-control" name="enabled"><option value="1" @if($enabled === '1') selected @endif>Enabled</option><option value="0" @if($enabled !== '1') selected @endif>Disabled</option></select></div><div class="form-group"><label>Rotation Seconds</label><input class="form-control" type="number" min="3" name="rotation_seconds" value="{{ $rotation_seconds }}"></div></div><div class="form-group"><label>Ad Source</label><select class="form-control" name="ad_source"><option value="custom" @if($ad_source === 'custom') selected @endif>Custom Ads Only</option><option value="adsense" @if($ad_source === 'adsense') selected @endif>Google AdSense Only</option><option value="both" @if($ad_source === 'both') selected @endif>Custom Ads + Google AdSense</option></select></div></div>

<div class="fc-s"><h3>Custom Ads</h3><div class="fc-m" style="margin-bottom:12px">Image URL ya HTML Code use karo. Show Chance se ad har page load par zaroori nahi dikhega.</div><input type="hidden" id="editIndex" value="-1">
<div class="fc-g"><div class="form-group"><label>Name</label><input id="adName" class="form-control" placeholder="Hosting Promo"></div><div class="form-group"><label>Type</label><select id="adType" class="form-control"><option value="image">Image URL</option><option value="html">HTML Code</option></select></div></div>
<div class="fc-g"><div class="form-group"><label>Priority</label><input id="adPriority" class="form-control" type="number" min="0" max="100" value="5"></div><div class="form-group"><label>Show Chance (%)</label><input id="adChance" class="form-control" type="number" min="0" max="100" value="70"><div class="fc-m">100 = always eligible, 70 = about 70%, 30 = rare.</div></div></div>
<div class="form-group"><label id="contentLabel">Banner Image URL</label><textarea id="adContent" class="form-control" rows="5" placeholder="https://example.com/banner.png"></textarea><div id="contentHelp" class="fc-m">Image URL paste karo.</div></div>
<div class="form-group"><label>Click URL (optional)</label><input id="adClick" class="form-control" placeholder="https://example.com/"></div>
<div class="fc-g"><div class="form-group"><label>Start Date</label><input id="adStart" class="form-control" type="datetime-local"></div><div class="form-group"><label>Expiry Date</label><input id="adEnd" class="form-control" type="datetime-local"></div></div>
<div class="form-group fc-l"><label style="display:block;font-weight:600">Locations</label><label><input class="fcLoc" type="checkbox" value="dashboard"> Dashboard</label><label><input class="fcLoc" type="checkbox" value="sidebar"> Sidebar</label><label><input class="fcLoc" type="checkbox" value="console"> Console</label><label><input class="fcLoc" type="checkbox" value="files"> Files</label><label><input class="fcLoc" type="checkbox" value="databases"> Databases</label><label><input class="fcLoc" type="checkbox" value="schedules"> Schedules</label><label><input class="fcLoc" type="checkbox" value="backups"> Backups</label><label><input class="fcLoc" type="checkbox" value="network"> Network</label><label><input class="fcLoc" type="checkbox" value="startup"> Startup</label><label><input class="fcLoc" type="checkbox" value="settings"> Settings</label><label><input class="fcLoc" type="checkbox" value="account"> Account</label><label><input class="fcLoc" type="checkbox" value="footer"> Footer</label></div>
<div class="form-group"><label>Status</label><select id="adStatus" class="form-control"><option value="active">Active</option><option value="disabled">Disabled</option></select></div>
<button type="button" id="saveAd" class="btn btn-success">Add / Update Ad</button> <button type="button" id="clearAd" class="btn btn-default">Clear</button><hr>
<div class="table-responsive"><table class="table table-bordered table-striped"><thead><tr><th>Name</th><th>Type</th><th>Locations</th><th>Chance</th><th>Status</th><th>Actions</th></tr></thead><tbody id="adsBody"></tbody></table></div></div>

<div class="fc-s"><h3>Google AdSense</h3><div class="alert alert-info">AdSense approval ke baad dedicated Publisher/Slot IDs use karo. AdSense code ko Custom HTML me mat daalo.</div><div class="form-group"><label>Publisher ID</label><input class="form-control" name="adsense_publisher_id" value="{{ $adsense_publisher_id }}" placeholder="ca-pub-xxxxxxxxxxxxxxxx"></div><div class="fc-g"><div class="form-group"><label>Dashboard Slot ID</label><input class="form-control" name="dashboard_slot_id" value="{{ $dashboard_slot_id }}"></div><div class="form-group"><label>Console Slot ID</label><input class="form-control" name="console_slot_id" value="{{ $console_slot_id }}"></div><div class="form-group"><label>Files Slot ID</label><input class="form-control" name="files_slot_id" value="{{ $files_slot_id }}"></div><div class="form-group"><label>Login Slot ID</label><input class="form-control" name="login_slot_id" value="{{ $login_slot_id }}"></div></div></div>
<div class="fc-s"><h3>Premium / No Ads Users</h3><textarea class="form-control" rows="6" name="excluded_users">{{ $excluded_users }}</textarea><div class="fc-m">Har line me ek email.</div></div>
<div style="text-align:right;margin-bottom:25px"><button class="btn btn-primary btn-lg" type="submit">Save Changes</button></div></form>

<script>
(function(){var h=document.getElementById('ads_json'),ads=[];try{ads=JSON.parse(h.value||'[]');if(!Array.isArray(ads))ads=[]}catch(e){ads=[]}function E(i){return document.getElementById(i)}function L(){var x=[];document.querySelectorAll('.fcLoc:checked').forEach(function(b){x.push(b.value)});return x}function mode(){var z=E('adType').value==='html';E('contentLabel').textContent=z?'HTML Code':'Banner Image URL';E('adContent').placeholder=z?'<div style="padding:15px">Your ad HTML here</div>':'https://example.com/banner.png';E('contentHelp').textContent=z?'Custom HTML/CSS snippet paste karo.':'Image URL paste karo.'}function clear(){E('editIndex').value='-1';E('adName').value='';E('adType').value='image';E('adPriority').value='5';E('adChance').value='70';E('adContent').value='';E('adClick').value='';E('adStart').value='';E('adEnd').value='';E('adStatus').value='active';document.querySelectorAll('.fcLoc').forEach(function(b){b.checked=false});var d=document.querySelector('.fcLoc[value="dashboard"]');if(d)d.checked=true;mode()}function sync(){h.value=JSON.stringify(ads);render()}function render(){var b=E('adsBody');b.innerHTML='';if(!ads.length){var r=document.createElement('tr'),c=document.createElement('td');c.colSpan=6;c.className='text-center text-muted';c.textContent='No custom ads yet.';r.appendChild(c);b.appendChild(r);return}ads.forEach(function(ad,i){var r=document.createElement('tr');function C(t){var c=document.createElement('td');c.textContent=t;return c}r.appendChild(C(ad.name||'Advertisement'));r.appendChild(C((ad.type||'image')==='html'?'HTML':'Image'));r.appendChild(C(Array.isArray(ad.locations)?ad.locations.join(', '):'dashboard'));r.appendChild(C(String(typeof ad.show_chance!=='undefined'?ad.show_chance:100)+'%'));r.appendChild(C(ad.status==='disabled'?'Disabled':'Active'));var a=document.createElement('td');a.className='fc-a';var e=document.createElement('button');e.type='button';e.className='btn btn-xs btn-primary';e.textContent='Edit';e.onclick=function(){edit(i)};var d=document.createElement('button');d.type='button';d.className='btn btn-xs btn-info';d.textContent='Duplicate';d.onclick=function(){var x=JSON.parse(JSON.stringify(ad));x.id='ad_'+Date.now();x.name=(x.name||'Ad')+' Copy';ads.push(x);sync()};var z=document.createElement('button');z.type='button';z.className='btn btn-xs btn-danger';z.textContent='Delete';z.onclick=function(){if(confirm('Delete this ad?')){ads.splice(i,1);sync();clear()}};a.appendChild(e);a.appendChild(d);a.appendChild(z);r.appendChild(a);b.appendChild(r)})}function edit(i){var ad=ads[i];if(!ad)return;E('editIndex').value=String(i);E('adName').value=ad.name||'';E('adType').value=ad.type==='html'?'html':'image';E('adPriority').value=typeof ad.priority!=='undefined'?ad.priority:5;E('adChance').value=typeof ad.show_chance!=='undefined'?ad.show_chance:100;E('adContent').value=ad.content||'';E('adClick').value=ad.click_url||'';E('adStart').value=ad.start_at||'';E('adEnd').value=ad.end_at||'';E('adStatus').value=ad.status||'active';var ls=Array.isArray(ad.locations)?ad.locations:['dashboard'];document.querySelectorAll('.fcLoc').forEach(function(b){b.checked=ls.indexOf(b.value)!==-1});mode();E('adName').scrollIntoView({behavior:'smooth',block:'center'})}E('adType').addEventListener('change',mode);E('saveAd').onclick=function(){var n=E('adName').value.trim(),c=E('adContent').value.trim(),ls=L();if(!n){alert('Ad name required');return}if(!c){alert('Ad content required');return}if(!ls.length){alert('At least 1 location select karo');return}var ad={id:'ad_'+Date.now(),name:n,type:E('adType').value,priority:Math.max(0,Math.min(100,parseInt(E('adPriority').value||'5',10))),show_chance:Math.max(0,Math.min(100,parseInt(E('adChance').value||'70',10))),content:c,click_url:E('adClick').value.trim(),locations:ls,status:E('adStatus').value,start_at:E('adStart').value,end_at:E('adEnd').value};var i=parseInt(E('editIndex').value,10);if(i>=0&&ads[i]){ad.id=ads[i].id||ad.id;ads[i]=ad}else ads.push(ad);sync();clear()};E('clearAd').onclick=clear;E('fcForm').addEventListener('submit',function(){h.value=JSON.stringify(ads)});clear();render()})();
</script>
BLADE

echo "[3/4] Admin UI updated"

cat > "$DEV/dashboard/wrapper.blade.php" <<'BLADE'
<style>
.fc-ad{position:relative;overflow:hidden;background:#111827;border:1px solid rgba(255,255,255,.10);border-radius:10px;box-shadow:0 5px 18px rgba(0,0,0,.22)}.fc-ad-main{width:100%;min-height:90px;margin:14px 0}.fc-ad-side{width:calc(100% - 18px);min-height:82px;margin:12px 9px}.fc-ad-footer{width:100%;min-height:76px;margin:18px 0}.fc-ad-image{width:100%;height:100px;object-fit:cover;display:block}.fc-ad-side .fc-ad-image{height:82px}.fc-ad-footer .fc-ad-image{height:76px}.fc-ad-html{width:100%;height:120px;border:0;background:transparent;display:block}.fc-ad-side .fc-ad-html{height:100px}.fc-ad-footer .fc-ad-html{height:100px}.fc-ad-top{display:flex;align-items:center;justify-content:space-between;padding:4px 7px;background:rgba(0,0,0,.34);font-size:10px;color:#fff}.fc-ad-close{border:0;background:rgba(0,0,0,.58);color:#fff;width:24px;height:24px;border-radius:5px;cursor:pointer;font-size:16px}.fc-ad-close:hover{background:rgba(185,28,28,.9)}.fc-sponsored{padding:5px 8px;color:#fff;font-size:10px;background:rgba(0,0,0,.38)}.fc-open{display:inline-block;margin:6px 8px 8px;padding:5px 9px;border-radius:5px;background:#2563eb;color:#fff!important;text-decoration:none;font-size:11px}
</style>
<script>
(function(){var timers={};function P(){var p=location.pathname;if(/^\/account/.test(p))return'account';if(/^\/server\/[^\/]+\/files/.test(p))return'files';if(/^\/server\/[^\/]+\/databases/.test(p))return'databases';if(/^\/server\/[^\/]+\/schedules/.test(p))return'schedules';if(/^\/server\/[^\/]+\/backups/.test(p))return'backups';if(/^\/server\/[^\/]+\/network/.test(p))return'network';if(/^\/server\/[^\/]+\/startup/.test(p))return'startup';if(/^\/server\/[^\/]+\/settings/.test(p))return'settings';if(/^\/server\/[^\/]+/.test(p))return'console';return'dashboard'}function K(s){return'fc_ad_closed::'+location.pathname+'::'+s}function R(id,cl){var x=document.getElementById(id);if(x)return x;x=document.createElement('div');x.id=id;x.className='fc-ad '+cl;x.style.display='none';return x}function eligible(a){if(!Array.isArray(a))return[];var o=[];a.forEach(function(ad){var c=parseInt(ad.show_chance,10);if(isNaN(c))c=100;c=Math.max(0,Math.min(100,c));if(Math.random()*100<=c)o.push(ad)});return o}function draw(r,ads,sec,slot){if(sessionStorage.getItem(K(slot))==='1'){r.style.display='none';return}ads=eligible(ads);if(!ads.length){r.style.display='none';return}var i=Math.floor(Math.random()*ads.length);function one(){var ad=ads[i];if(!ad||!ad.content){r.style.display='none';return}r.innerHTML='';var top=document.createElement('div');top.className='fc-ad-top';var lab=document.createElement('span');lab.textContent='Ad';var close=document.createElement('button');close.type='button';close.className='fc-ad-close';close.textContent='×';close.onclick=function(e){e.preventDefault();e.stopPropagation();sessionStorage.setItem(K(slot),'1');if(timers[r.id])clearInterval(timers[r.id]);r.style.display='none'};top.appendChild(lab);top.appendChild(close);r.appendChild(top);if((ad.type||'image')==='html'){var f=document.createElement('iframe');f.className='fc-ad-html';f.setAttribute('title',ad.name||'Advertisement');f.setAttribute('sandbox','allow-scripts allow-forms allow-popups allow-popups-to-escape-sandbox');f.srcdoc=ad.content;r.appendChild(f);if(ad.click_url){var o=document.createElement('a');o.className='fc-open';o.href=ad.click_url;o.target='_blank';o.rel='noopener noreferrer sponsored';o.textContent='Open sponsor';r.appendChild(o)}}else{var img=document.createElement('img');img.className='fc-ad-image';img.src=ad.content;img.alt=ad.name||'Advertisement';img.onerror=function(){r.style.display='none'};if(ad.click_url){var a=document.createElement('a');a.href=ad.click_url;a.target='_blank';a.rel='noopener noreferrer sponsored';a.appendChild(img);r.appendChild(a)}else r.appendChild(img)}var s=document.createElement('div');s.className='fc-sponsored';s.textContent='Sponsored • '+(ad.name||'Advertisement');r.appendChild(s);r.style.display='block'}one();if(timers[r.id])clearInterval(timers[r.id]);if(ads.length>1)timers[r.id]=setInterval(function(){if(sessionStorage.getItem(K(slot))==='1')return;i=(i+1)%ads.length;one()},Math.max(3,sec||7)*1000)}function load(r,p,s){fetch('/api/client/extensions/fakecloudadsmanager/config?placement='+encodeURIComponent(p),{credentials:'same-origin',headers:{Accept:'application/json'}}).then(function(x){return x.json()}).then(function(d){if(d&&d.enabled&&Array.isArray(d.ads))draw(r,d.ads,parseInt(d.rotation_seconds||7,10),s);else r.style.display='none'}).catch(function(e){console.error('FakeCloud Ads',e);r.style.display='none'})}function side(){var a=document.querySelectorAll('aside,nav,div'),b=null;for(var i=0;i<a.length;i++){var e=a[i],r=e.getBoundingClientRect(),t=(e.innerText||'').toLowerCase();if(r.left<30&&r.width>150&&r.width<330&&r.height>400&&t.indexOf('servers')!==-1&&t.indexOf('account')!==-1)b=e}return b}function main(){var m=document.querySelector('main')||document.querySelector('[role="main"]');if(m)return m;var a=document.querySelectorAll('div'),b=null,z=0;for(var i=0;i<a.length;i++){var r=a[i].getBoundingClientRect(),q=r.width*r.height;if(r.left>180&&r.width>500&&r.height>250&&q>z){b=a[i];z=q}}return b}function card(){var s=document.querySelector('a[href^="/server/"]');if(!s)return null;var c=s;for(var i=0;i<12&&c.parentElement;i++){var r=c.getBoundingClientRect();if(r.width>=400&&r.width<=1100&&r.height>=130&&r.height<=550)break;c=c.parentElement}return c}function mount(){var p=P(),m=main(),page=R('fc-page-ad','fc-ad-main'),sbx=R('fc-side-ad','fc-ad-side'),foot=R('fc-footer-ad','fc-ad-footer');if(p==='dashboard'){var c=card();if(c&&c.parentElement&&!document.body.contains(page))c.parentElement.insertBefore(page,c.nextSibling)}else if(m&&!document.body.contains(page)){var h=m.querySelector('h1,h2,h3');if(h&&h.parentElement)h.parentElement.insertBefore(page,h.nextSibling);else m.insertBefore(page,m.firstChild)}var sb=side();if(sb&&!document.body.contains(sbx))sb.appendChild(sbx);if(m&&!document.body.contains(foot))m.appendChild(foot);if(page.dataset.p!==p){page.dataset.p=p;load(page,p,'page')}if(!sbx.dataset.loaded){sbx.dataset.loaded='1';load(sbx,'sidebar','sidebar')}if(foot.dataset.p!==p){foot.dataset.p=p;load(foot,'footer','footer')}}var op=history.pushState;history.pushState=function(){op.apply(history,arguments);setTimeout(mount,400)};var or=history.replaceState;history.replaceState=function(){or.apply(history,arguments);setTimeout(mount,400)};addEventListener('popstate',function(){setTimeout(mount,400)});new MutationObserver(mount).observe(document.documentElement,{childList:true,subtree:true});setTimeout(mount,300);setTimeout(mount,1000);setTimeout(mount,2500)})();
</script>
BLADE

echo "[4/4] Visible-only renderer updated"
php -l "$DEV/app/AdsController.php"
cd "$PANEL"
blueprint -build
php artisan view:clear
php artisan optimize:clear

echo
echo "===================================================="
echo " FakeCloud Ads Manager V4 patch installed"
echo " - invisible click layer removed"
echo " - close (X) on every ad"
echo " - Image URL + HTML Code"
echo " - per-ad Show Chance (%)"
echo " - random ad selection / rotation"
echo " Backup: $BACKUP"
echo " Ctrl + Shift + R in browser"
echo "===================================================="
