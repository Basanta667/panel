#!/usr/bin/env bash
set -euo pipefail

PANEL="/var/www/pterodactyl"
DEV="$PANEL/.blueprint/dev"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="/root/fakecloud-ads-backup-$STAMP"

if [ ! -d "$DEV" ]; then
  echo "ERROR: Blueprint dev folder not found: $DEV"
  exit 1
fi

mkdir -p "$BACKUP"
cp -a "$DEV/admin/view.blade.php" "$BACKUP/" 2>/dev/null || true
cp -a "$DEV/app/AdsController.php" "$BACKUP/" 2>/dev/null || true
cp -a "$DEV/dashboard/wrapper.blade.php" "$BACKUP/" 2>/dev/null || true

echo "[1/5] Backup: $BACKUP"

mkdir -p "$DEV/admin" "$DEV/app" "$DEV/dashboard"

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
        $value = DB::table('settings')
            ->where('key', 'fakecloudadsmanager::' . $key)
            ->value('value');

        return $value === null ? $default : (string) $value;
    }

    public function config(Request $request): JsonResponse
    {
        $enabled = strtolower($this->setting('enabled', '1'));

        if (!in_array($enabled, ['1', 'true', 'yes', 'enabled'], true)) {
            return response()->json(['enabled' => false]);
        }

        $excludedRaw = $this->setting(
            'excluded_users',
            $this->setting('premium_emails', '')
        );

        $excluded = preg_split('/[\r\n,]+/', strtolower($excludedRaw), -1, PREG_SPLIT_NO_EMPTY);
        $excluded = array_map('trim', $excluded ?: []);
        $user = $request->user();

        if ($user && in_array(strtolower((string) $user->email), $excluded, true)) {
            return response()->json(['enabled' => false, 'premium' => true]);
        }

        $allowed = [
            'dashboard','sidebar','console','files','databases','schedules',
            'backups','network','startup','settings','account','footer',
        ];

        $placement = strtolower((string) $request->query('placement', 'dashboard'));

        if (!in_array($placement, $allowed, true)) {
            $placement = 'dashboard';
        }

        $decoded = json_decode($this->setting('ads_json', '[]'), true);
        $stored = is_array($decoded) ? $decoded : [];
        $now = time();
        $ads = [];

        foreach ($stored as $ad) {
            if (!is_array($ad)) continue;
            if (($ad['status'] ?? 'active') !== 'active') continue;

            $locations = isset($ad['locations']) && is_array($ad['locations'])
                ? $ad['locations']
                : ['dashboard'];

            if (!in_array($placement, $locations, true)) continue;

            $start = trim((string) ($ad['start_at'] ?? ''));
            $end = trim((string) ($ad['end_at'] ?? ''));

            if ($start !== '' && strtotime($start) > $now) continue;
            if ($end !== '' && strtotime($end) < $now) continue;

            $content = trim((string) ($ad['content'] ?? ''));
            if ($content === '') continue;

            $ads[] = [
                'id' => (string) ($ad['id'] ?? ''),
                'name' => (string) ($ad['name'] ?? 'Advertisement'),
                'type' => (string) ($ad['type'] ?? 'image'),
                'priority' => (int) ($ad['priority'] ?? 5),
                'content' => $content,
                'click_url' => (string) ($ad['click_url'] ?? ''),
            ];
        }

        usort($ads, function ($a, $b) {
            return (int) ($b['priority'] ?? 0) <=> (int) ($a['priority'] ?? 0);
        });

        if (count($ads) === 0 && $placement === 'dashboard') {
            $banner = trim($this->setting('banner_url', ''));

            if ($banner !== '') {
                $ads[] = [
                    'id' => 'legacy',
                    'name' => $this->setting('advertiser', 'Advertisement'),
                    'type' => 'image',
                    'priority' => 5,
                    'content' => $banner,
                    'click_url' => $this->setting('click_url', ''),
                ];
            }
        }

        return response()->json([
            'enabled' => count($ads) > 0,
            'placement' => $placement,
            'rotation_seconds' => max(3, (int) $this->setting('rotation_seconds', '7')),
            'ads' => $ads,
        ]);
    }
}
PHP

echo "[2/5] API controller written."

cat > "$DEV/admin/view.blade.php" <<'BLADE'
<style>
.fc-head{position:sticky;top:0;z-index:40;background:#08082b;border:1px solid #4936c9;border-radius:8px;padding:12px 14px;margin-bottom:16px;display:flex;justify-content:space-between;align-items:center}
.fc-head-title{font-size:19px;font-weight:600}
.fc-section{background:#08082b;border:1px solid rgba(95,65,220,.65);border-radius:8px;padding:16px;margin-bottom:18px}
.fc-section h3{margin:0 0 15px}
.fc-grid{display:grid;grid-template-columns:1fr 1fr;gap:14px}
.fc-locs label{display:inline-block;margin:5px 14px 5px 0;font-weight:400}
.fc-muted{opacity:.7;font-size:12px}
.fc-actions button{margin-right:4px}
@media(max-width:800px){.fc-grid{grid-template-columns:1fr}}
</style>

<form method="POST" action="" id="fcForm">
    {{ csrf_field() }}
    <input type="hidden" name="_method" value="PATCH">
    <textarea name="ads_json" id="ads_json" style="display:none;">{{ $ads_json }}</textarea>

    <div class="fc-head">
        <div>
            <div class="fc-head-title"><i class="fa fa-bullhorn"></i> FakeCloud Ads Manager</div>
            <div class="fc-muted">Custom Ads + Google AdSense + Premium Users</div>
        </div>
        <button class="btn btn-primary" type="submit"><i class="fa fa-save"></i> Save Changes</button>
    </div>

    <div class="fc-section">
        <h3><i class="fa fa-cogs"></i> Global Settings</h3>
        <div class="fc-grid">
            <div class="form-group">
                <label>Ads Status</label>
                <select class="form-control" name="enabled">
                    <option value="1" @if($enabled === '1') selected @endif>Enabled</option>
                    <option value="0" @if($enabled !== '1') selected @endif>Disabled</option>
                </select>
            </div>
            <div class="form-group">
                <label>Rotation Seconds</label>
                <input class="form-control" type="number" min="3" name="rotation_seconds" value="{{ $rotation_seconds }}">
            </div>
        </div>
        <div class="form-group">
            <label>Ad Source</label>
            <select class="form-control" name="ad_source">
                <option value="custom" @if($ad_source === 'custom') selected @endif>Custom Ads Only</option>
                <option value="adsense" @if($ad_source === 'adsense') selected @endif>Google AdSense Only</option>
                <option value="both" @if($ad_source === 'both') selected @endif>Custom Ads + Google AdSense</option>
            </select>
        </div>
    </div>

    <div class="fc-section">
        <h3><i class="fa fa-picture-o"></i> Custom Ads</h3>
        <div class="fc-muted" style="margin-bottom:12px;">Unlimited ads. Har ad ki location alag select kar sakte ho.</div>
        <input type="hidden" id="editIndex" value="-1">

        <div class="fc-grid">
            <div class="form-group"><label>Name</label><input id="adName" class="form-control" placeholder="Hosting Promo"></div>
            <div class="form-group"><label>Priority</label><input id="adPriority" class="form-control" type="number" min="0" max="100" value="5"></div>
        </div>

        <div class="form-group"><label>Banner Image URL</label><input id="adContent" class="form-control" placeholder="https://example.com/banner.png"></div>
        <div class="form-group"><label>Click URL</label><input id="adClick" class="form-control" placeholder="https://example.com/"></div>

        <div class="fc-grid">
            <div class="form-group"><label>Start Date (optional)</label><input id="adStart" class="form-control" type="datetime-local"></div>
            <div class="form-group"><label>Expiry Date (optional)</label><input id="adEnd" class="form-control" type="datetime-local"></div>
        </div>

        <div class="form-group fc-locs">
            <label style="display:block;font-weight:600;">Locations</label>
            <label><input class="fcLoc" type="checkbox" value="dashboard"> Dashboard</label>
            <label><input class="fcLoc" type="checkbox" value="sidebar"> Sidebar</label>
            <label><input class="fcLoc" type="checkbox" value="console"> Console</label>
            <label><input class="fcLoc" type="checkbox" value="files"> Files</label>
            <label><input class="fcLoc" type="checkbox" value="databases"> Databases</label>
            <label><input class="fcLoc" type="checkbox" value="schedules"> Schedules</label>
            <label><input class="fcLoc" type="checkbox" value="backups"> Backups</label>
            <label><input class="fcLoc" type="checkbox" value="network"> Network</label>
            <label><input class="fcLoc" type="checkbox" value="startup"> Startup</label>
            <label><input class="fcLoc" type="checkbox" value="settings"> Settings</label>
            <label><input class="fcLoc" type="checkbox" value="account"> Account</label>
            <label><input class="fcLoc" type="checkbox" value="footer"> Footer</label>
        </div>

        <div class="form-group">
            <label>Status</label>
            <select id="adStatus" class="form-control"><option value="active">Active</option><option value="disabled">Disabled</option></select>
        </div>

        <button type="button" id="saveAd" class="btn btn-success"><i class="fa fa-plus"></i> Add / Update Ad</button>
        <button type="button" id="clearAd" class="btn btn-default">Clear</button>

        <hr>
        <div class="table-responsive">
            <table class="table table-bordered table-striped">
                <thead><tr><th>Name</th><th>Locations</th><th>Priority</th><th>Status</th><th>Actions</th></tr></thead>
                <tbody id="adsBody"></tbody>
            </table>
        </div>
    </div>

    <div class="fc-section">
        <h3><i class="fa fa-google"></i> Google AdSense</h3>
        <div class="alert alert-info">AdSense Ready hone ke baad real IDs yahan daalo.</div>
        <div class="form-group"><label>Publisher ID</label><input class="form-control" name="adsense_publisher_id" value="{{ $adsense_publisher_id }}" placeholder="ca-pub-4599991036355439"></div>
        <div class="fc-grid">
            <div class="form-group"><label>Dashboard Slot ID</label><input class="form-control" name="dashboard_slot_id" value="{{ $dashboard_slot_id }}"></div>
            <div class="form-group"><label>Console Slot ID</label><input class="form-control" name="console_slot_id" value="{{ $console_slot_id }}"></div>
            <div class="form-group"><label>Files Slot ID</label><input class="form-control" name="files_slot_id" value="{{ $files_slot_id }}"></div>
            <div class="form-group"><label>Login Slot ID</label><input class="form-control" name="login_slot_id" value="{{ $login_slot_id }}"></div>
        </div>
    </div>

    <div class="fc-section">
        <h3><i class="fa fa-star"></i> Premium / No Ads Users</h3>
        <textarea class="form-control" rows="6" name="excluded_users" placeholder="one@email.com&#10;two@email.com">{{ $excluded_users }}</textarea>
        <div class="fc-muted">Har line me ek email. In users ko ads nahi dikhengi.</div>
    </div>

    <div style="text-align:right;margin-bottom:25px;">
        <button class="btn btn-primary btn-lg" type="submit"><i class="fa fa-save"></i> Save Changes</button>
    </div>
</form>

<script>
(function(){
var hidden=document.getElementById('ads_json'),ads=[];
try{ads=JSON.parse(hidden.value||'[]');if(!Array.isArray(ads))ads=[];}catch(e){ads=[];}
function E(id){return document.getElementById(id);}
function locs(){var x=[];document.querySelectorAll('.fcLoc:checked').forEach(function(b){x.push(b.value);});return x;}
function clearForm(){E('editIndex').value='-1';E('adName').value='';E('adPriority').value='5';E('adContent').value='';E('adClick').value='';E('adStart').value='';E('adEnd').value='';E('adStatus').value='active';document.querySelectorAll('.fcLoc').forEach(function(b){b.checked=false;});var d=document.querySelector('.fcLoc[value="dashboard"]');if(d)d.checked=true;}
function sync(){hidden.value=JSON.stringify(ads);render();}
function render(){
var body=E('adsBody');body.innerHTML='';
if(!ads.length){var r=document.createElement('tr'),c=document.createElement('td');c.colSpan=5;c.className='text-center text-muted';c.textContent='No custom ads yet.';r.appendChild(c);body.appendChild(r);return;}
ads.forEach(function(ad,i){
var r=document.createElement('tr');
function cell(t){var c=document.createElement('td');c.textContent=t;return c;}
r.appendChild(cell(ad.name||'Advertisement'));r.appendChild(cell(Array.isArray(ad.locations)?ad.locations.join(', '):'dashboard'));r.appendChild(cell(String(typeof ad.priority!=='undefined'?ad.priority:5)));r.appendChild(cell(ad.status==='disabled'?'Disabled':'Active'));
var a=document.createElement('td');a.className='fc-actions';
var e=document.createElement('button');e.type='button';e.className='btn btn-xs btn-primary';e.textContent='Edit';e.onclick=function(){editAd(i);};
var d=document.createElement('button');d.type='button';d.className='btn btn-xs btn-info';d.textContent='Duplicate';d.onclick=function(){var x=JSON.parse(JSON.stringify(ad));x.id='ad_'+Date.now();x.name=(x.name||'Ad')+' Copy';ads.push(x);sync();};
var z=document.createElement('button');z.type='button';z.className='btn btn-xs btn-danger';z.textContent='Delete';z.onclick=function(){if(confirm('Delete this ad?')){ads.splice(i,1);sync();clearForm();}};
a.appendChild(e);a.appendChild(d);a.appendChild(z);r.appendChild(a);body.appendChild(r);
});}
function editAd(i){var ad=ads[i];if(!ad)return;E('editIndex').value=String(i);E('adName').value=ad.name||'';E('adPriority').value=typeof ad.priority!=='undefined'?ad.priority:5;E('adContent').value=ad.content||'';E('adClick').value=ad.click_url||'';E('adStart').value=ad.start_at||'';E('adEnd').value=ad.end_at||'';E('adStatus').value=ad.status||'active';var ls=Array.isArray(ad.locations)?ad.locations:['dashboard'];document.querySelectorAll('.fcLoc').forEach(function(b){b.checked=ls.indexOf(b.value)!==-1;});E('adName').scrollIntoView({behavior:'smooth',block:'center'});}
E('saveAd').onclick=function(){var name=E('adName').value.trim(),content=E('adContent').value.trim(),ls=locs();if(!name){alert('Ad name required');return;}if(!content){alert('Banner Image URL required');return;}if(!ls.length){alert('At least 1 location select karo');return;}var ad={id:'ad_'+Date.now(),name:name,type:'image',priority:parseInt(E('adPriority').value||'5',10),content:content,click_url:E('adClick').value.trim(),locations:ls,status:E('adStatus').value,start_at:E('adStart').value,end_at:E('adEnd').value};var i=parseInt(E('editIndex').value,10);if(i>=0&&ads[i]){ad.id=ads[i].id||ad.id;ads[i]=ad;}else{ads.push(ad);}sync();clearForm();};
E('clearAd').onclick=clearForm;E('fcForm').addEventListener('submit',function(){hidden.value=JSON.stringify(ads);});clearForm();render();
})();
</script>
BLADE

echo "[3/5] Admin UI written."

cat > "$DEV/dashboard/wrapper.blade.php" <<'BLADE'
<style>
.fc-ad{position:relative;overflow:hidden;background:#111827;border:1px solid rgba(255,255,255,.08);border-radius:9px;box-shadow:0 5px 18px rgba(0,0,0,.22)}
.fc-ad-main{width:100%;height:90px;margin:14px 0}.fc-ad-side{width:calc(100% - 18px);height:82px;margin:12px 9px}.fc-ad-footer{width:100%;height:76px;margin:18px 0}
.fc-ad img{width:100%;height:100%;object-fit:cover;display:block}.fc-ad a{display:block;width:100%;height:100%}
.fc-tag{position:absolute;right:6px;top:6px;background:rgba(0,0,0,.72);color:#fff;padding:2px 6px;border-radius:3px;font-size:9px;z-index:5;pointer-events:none}
.fc-sponsored{position:absolute;left:0;right:0;bottom:0;padding:12px 7px 4px;background:linear-gradient(transparent,rgba(0,0,0,.85));color:#fff;font-size:10px;z-index:4;pointer-events:none}
</style>
<script>
(function(){
var timers={};
function placement(){var p=location.pathname;if(/^\/account/.test(p))return'account';if(/^\/server\/[^\/]+\/files/.test(p))return'files';if(/^\/server\/[^\/]+\/databases/.test(p))return'databases';if(/^\/server\/[^\/]+\/schedules/.test(p))return'schedules';if(/^\/server\/[^\/]+\/backups/.test(p))return'backups';if(/^\/server\/[^\/]+\/network/.test(p))return'network';if(/^\/server\/[^\/]+\/startup/.test(p))return'startup';if(/^\/server\/[^\/]+\/settings/.test(p))return'settings';if(/^\/server\/[^\/]+/.test(p))return'console';return'dashboard';}
function root(id,cls){var x=document.getElementById(id);if(x)return x;x=document.createElement('div');x.id=id;x.className='fc-ad '+cls;x.style.display='none';return x;}
function draw(r,ads,sec){if(!ads||!ads.length){r.style.display='none';return;}var i=0;function one(){var ad=ads[i];if(!ad||!ad.content)return;r.innerHTML='';var img=document.createElement('img');img.src=ad.content;img.alt=ad.name||'Advertisement';img.onerror=function(){r.style.display='none';};if(ad.click_url){var a=document.createElement('a');a.href=ad.click_url;a.target='_blank';a.rel='noopener noreferrer sponsored';a.appendChild(img);r.appendChild(a);}else r.appendChild(img);var t=document.createElement('div');t.className='fc-tag';t.textContent='Ad';r.appendChild(t);var s=document.createElement('div');s.className='fc-sponsored';s.textContent='Sponsored • '+(ad.name||'Advertisement');r.appendChild(s);r.style.display='block';}one();if(timers[r.id])clearInterval(timers[r.id]);if(ads.length>1)timers[r.id]=setInterval(function(){i=(i+1)%ads.length;one();},Math.max(3,sec||7)*1000);}
function load(r,p){fetch('/api/client/extensions/fakecloudadsmanager/config?placement='+encodeURIComponent(p),{credentials:'same-origin',headers:{Accept:'application/json'}}).then(function(x){return x.json();}).then(function(d){if(d&&d.enabled&&Array.isArray(d.ads))draw(r,d.ads,parseInt(d.rotation_seconds||7,10));else r.style.display='none';}).catch(function(e){console.error('FakeCloud Ads',e);});}
function sidebar(){var all=document.querySelectorAll('aside,nav,div'),best=null;for(var i=0;i<all.length;i++){var e=all[i],r=e.getBoundingClientRect(),t=(e.innerText||'').toLowerCase();if(r.left<30&&r.width>150&&r.width<330&&r.height>400&&t.indexOf('servers')!==-1&&t.indexOf('account')!==-1)best=e;}return best;}
function main(){var m=document.querySelector('main')||document.querySelector('[role="main"]');if(m)return m;var all=document.querySelectorAll('div'),best=null,area=0;for(var i=0;i<all.length;i++){var r=all[i].getBoundingClientRect(),a=r.width*r.height;if(r.left>180&&r.width>500&&r.height>250&&a>area){best=all[i];area=a;}}return best;}
function serverCard(){var s=document.querySelector('a[href^="/server/"]');if(!s)return null;var c=s;for(var i=0;i<12&&c.parentElement;i++){var r=c.getBoundingClientRect();if(r.width>=400&&r.width<=1100&&r.height>=130&&r.height<=550)break;c=c.parentElement;}return c;}
function mount(){var p=placement(),m=main(),page=root('fc-page-ad','fc-ad-main'),side=root('fc-side-ad','fc-ad-side'),foot=root('fc-footer-ad','fc-ad-footer');if(p==='dashboard'){var c=serverCard();if(c&&c.parentElement)c.parentElement.insertBefore(page,c.nextSibling);}else if(m&&!document.body.contains(page)){var h=m.querySelector('h1,h2,h3');if(h&&h.parentElement)h.parentElement.insertBefore(page,h.nextSibling);else m.insertBefore(page,m.firstChild);}var sb=sidebar();if(sb&&!document.body.contains(side))sb.appendChild(side);if(m&&!document.body.contains(foot))m.appendChild(foot);if(page.dataset.p!==p){page.dataset.p=p;load(page,p);}if(!side.dataset.loaded){side.dataset.loaded='1';load(side,'sidebar');}if(foot.dataset.p!==p){foot.dataset.p=p;load(foot,'footer');}}
var oldPush=history.pushState;history.pushState=function(){oldPush.apply(history,arguments);setTimeout(mount,400);};var oldReplace=history.replaceState;history.replaceState=function(){oldReplace.apply(history,arguments);setTimeout(mount,400);};addEventListener('popstate',function(){setTimeout(mount,400);});var obs=new MutationObserver(function(){mount();});obs.observe(document.documentElement,{childList:true,subtree:true});setTimeout(mount,300);setTimeout(mount,1000);setTimeout(mount,2500);
})();
</script>
BLADE

echo "[4/5] Multi-location renderer written."

php -l "$DEV/app/AdsController.php"

cd "$PANEL"
blueprint -build
php artisan view:clear
php artisan optimize:clear

echo
echo "============================================"
echo "FakeCloud Ads Manager V3 installed"
echo "Backup: $BACKUP"
echo "Now hard refresh: Ctrl + Shift + R"
echo "============================================"
