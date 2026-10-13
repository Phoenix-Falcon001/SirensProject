"""Render results: console text, a static PNG link chart, and a self-contained
interactive HTML link-analysis view (no external assets — runs offline).
"""
from __future__ import annotations

import html
import json
import pathlib

from .models import Cluster, Incident, Link


# ---------------------------------------------------------------- console ----
def console_report(incidents, links: list[Link], clusters: list[Cluster]) -> str:
    lines = []
    lines.append("=" * 70)
    lines.append(f" C-IED LINK ANALYSIS — {len(incidents)} incidents, "
                 f"{len(links)} links, {len(clusters)} clusters")
    lines.append("=" * 70)

    if not clusters:
        lines.append("  No multi-incident clusters above threshold.")
    for c in clusters:
        lines.append("")
        lines.append(f"  ▣ {c.cluster_id}  ({c.size} incidents)")
        lines.append(f"      members   : {', '.join(c.members)}")
        lines.append(f"      signature : {', '.join(c.signature) or '(no dominant shared features)'}")
        lines.append(f"      strongest links:")
        for l in c.internal_links[:4]:
            lines.append(f"        {l.a} ↔ {l.b}  score={l.score}")
            for r in l.reasons:
                lines.append(f"            – {r}")
    lines.append("")
    lines.append("  Top links overall:")
    for l in links[:8]:
        lines.append(f"    {l.a} ↔ {l.b}  score={l.score}  "
                     f"[{'; '.join(l.reasons)}]")
    return "\n".join(lines)


# ------------------------------------------------------------------- PNG -----
def static_graph_png(clusterer, path: str | pathlib.Path) -> pathlib.Path:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    import networkx as nx

    g = clusterer.graph
    clusters = clusterer.clusters(singletons=True)
    palette = ["#e0b64a", "#4ac5e0", "#e07a5f", "#8bd450", "#b78be0",
               "#e04a7a", "#5f8be0", "#9aa0a6"]
    node_color = {}
    for i, c in enumerate(clusters):
        for m in c.members:
            node_color[m] = palette[i % len(palette)] if c.size > 1 else "#5b6168"

    pos = nx.spring_layout(g, seed=7, k=0.9)
    fig, ax = plt.subplots(figsize=(11, 8))
    fig.patch.set_facecolor("#12161a")
    ax.set_facecolor("#12161a")
    for u, v, d in g.edges(data=True):
        ax.plot([pos[u][0], pos[v][0]], [pos[u][1], pos[v][1]],
                color="#3a4149", linewidth=0.6 + 3 * d["weight"], zorder=1)
    xs = [pos[n][0] for n in g.nodes()]
    ys = [pos[n][1] for n in g.nodes()]
    ax.scatter(xs, ys, s=420,
               c=[node_color.get(n, "#5b6168") for n in g.nodes()],
               edgecolors="#0c0f12", linewidths=1.5, zorder=2)
    for n in g.nodes():
        ax.annotate(n, pos[n], color="#e8eaed", fontsize=7.5,
                    ha="center", va="center", zorder=3, fontweight="bold")
    ax.set_title("C-IED Incident Link Chart", color="#e8eaed", fontsize=13, pad=14)
    ax.axis("off")
    out = pathlib.Path(path)
    fig.savefig(out, dpi=140, bbox_inches="tight", facecolor="#12161a")
    plt.close(fig)
    return out


# ------------------------------------------------------------------ HTML -----
_CONSOLE_LINK = ('<a href="http://127.0.0.1:5000/" style="color:#8b96a2;font-family:ui-monospace,'
                 'Menlo,Consolas,monospace;font-size:11px;text-decoration:none;border:1px solid #2a323b;'
                 'padding:5px 10px;border-radius:4px">&#8592; console</a>')


def html_report(incidents, links, clusters, graph_payload,
                title: str = "C-IED Incident Link Analysis", nav: str = "") -> str:
    """Self-contained HTML link chart. `nav` is the web app's shared menu
    (ui_menu.menu); standalone files from the CLI get a plain console link."""
    data_json = json.dumps(graph_payload)
    clusters_json = json.dumps([c.to_dict() for c in clusters])
    inc_json = json.dumps({i.incident_id: i.to_dict() for i in incidents})

    return _HTML_TEMPLATE.format(
        title=html.escape(title),
        nav=nav or _CONSOLE_LINK,
        n_inc=len(incidents),
        n_link=len(links),
        n_clu=len(clusters),
        data_json=data_json,
        clusters_json=clusters_json,
        inc_json=inc_json,
    )


_HTML_TEMPLATE = r"""<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<style>
  :root {{
    --bg:#0e1216; --panel:#161b21; --panel-2:#1d242c; --line:#2a323b;
    --ink:#e6e9ec; --muted:#8b96a2; --accent:#e0b64a; --accent-2:#4ac5e0;
    --block:#c8402f;
  }}
  * {{ box-sizing:border-box; }}
  html,body {{ margin:0; height:100%; background:var(--bg); color:var(--ink);
    font-family:ui-sans-serif,-apple-system,"Segoe UI",Roboto,sans-serif; }}
  .wrap {{ display:grid; grid-template-columns: 1fr 340px; grid-template-rows:auto 1fr;
    height:100vh; min-height:0; }}
  header {{ grid-column:1 / -1; display:flex; align-items:baseline; gap:20px;
    padding:14px 20px; border-bottom:1px solid var(--line); background:var(--panel); }}
  header h1 {{ font-size:15px; letter-spacing:.14em; text-transform:uppercase;
    margin:0; font-weight:700; }}
  header .stats {{ font-size:12px; color:var(--muted); letter-spacing:.05em;
    font-variant-numeric:tabular-nums; }}
  header .stats b {{ color:var(--accent); font-weight:700; }}
  #stage {{ position:relative; overflow:hidden; min-height:520px; min-width:0; }}
  canvas {{ display:block; width:100%; height:100%; }}
  aside {{ background:var(--panel); border-left:1px solid var(--line);
    overflow-y:auto; padding:0; }}
  .side-h {{ font-size:11px; letter-spacing:.16em; text-transform:uppercase;
    color:var(--muted); padding:14px 16px 8px; }}
  .cluster {{ margin:0 12px 10px; background:var(--panel-2); border:1px solid var(--line);
    border-radius:8px; padding:10px 12px; cursor:pointer; }}
  .cluster:hover {{ border-color:var(--accent); }}
  .cluster .cid {{ font-family:ui-monospace,Menlo,Consolas,monospace; font-weight:700;
    color:var(--accent); font-size:13px; }}
  .cluster .sz {{ color:var(--muted); font-size:11px; float:right; }}
  .cluster .sig {{ font-size:11.5px; color:var(--ink); margin-top:6px; line-height:1.5; }}
  .cluster .sig span {{ display:inline-block; background:#12181e; border:1px solid var(--line);
    border-radius:4px; padding:1px 6px; margin:2px 3px 0 0;
    font-family:ui-monospace,Menlo,Consolas,monospace; font-size:10.5px; color:var(--accent-2); }}
  .cluster .mem {{ font-size:10.5px; color:var(--muted); margin-top:7px;
    font-family:ui-monospace,Menlo,Consolas,monospace; }}
  #tip {{ position:absolute; pointer-events:none; z-index:9; max-width:280px;
    background:#0b0f13ee; border:1px solid var(--accent); border-radius:8px;
    padding:9px 11px; font-size:11.5px; line-height:1.5; display:none;
    box-shadow:0 8px 30px #0008; }}
  #tip h4 {{ margin:0 0 5px; font-family:ui-monospace,monospace; color:var(--accent);
    font-size:12.5px; letter-spacing:.05em; }}
  #tip .k {{ color:var(--muted); }}
  #tip code {{ color:var(--accent-2); }}
  .legend {{ position:absolute; left:14px; bottom:12px; font-size:11px; color:var(--muted);
    background:#0b0f13cc; border:1px solid var(--line); border-radius:8px; padding:8px 10px; }}
  .legend b {{ color:var(--ink); }}
  .hint {{ position:absolute; right:14px; bottom:12px; font-size:10.5px; color:var(--muted); }}
</style></head>
<body>
<div class="wrap">
  <header>
    <h1>{title}</h1>
    {nav}
    <div class="stats">INCIDENTS <b>{n_inc}</b> &nbsp;·&nbsp; LINKS <b>{n_link}</b>
      &nbsp;·&nbsp; CLUSTERS <b>{n_clu}</b></div>
  </header>
  <div id="stage">
    <canvas id="c"></canvas>
    <div id="tip"></div>
    <div class="legend">Node = incident · edge = link · thicker = stronger.<br>
      <b>Colour = cluster.</b> Grey = unlinked.<br>
      Scroll to zoom · drag empty space to pan · drag a node to move it.<br>
      Hover a node to see exactly what it connects to.</div>
    <div class="hint">force-directed · offline</div>
  </div>
  <aside>
    <div class="side-h">Candidate networks / signatures</div>
    <div id="clusters"></div>
  </aside>
</div>
<script>
const GRAPH = {data_json};
const CLUSTERS = {clusters_json};
const INC = {inc_json};
const PALETTE = ["#e0b64a","#4ac5e0","#e07a5f","#8bd450","#b78be0","#e04a7a","#5f8be0"];
const cidColor = {{}};
CLUSTERS.forEach((c,i)=>{{ cidColor[c.cluster_id]=PALETTE[i%PALETTE.length]; }});

const canvas=document.getElementById('c'), ctx=canvas.getContext('2d');
let W=0,H=0,DPR=window.devicePixelRatio||1;
function resize(){{ const r=canvas.parentElement.getBoundingClientRect();
  W=Math.max(r.width, 320) || Math.max(window.innerWidth-340,320);
  H=Math.max(r.height,320) || Math.max(window.innerHeight-60,320);
  canvas.width=W*DPR;canvas.height=H*DPR;ctx.setTransform(DPR,0,0,DPR,0,0); }}
window.addEventListener('resize',resize);
window.addEventListener('load',()=>{{resize();recenter();}});
resize();

const nodes=GRAPH.nodes.map((n,i)=>({{
  ...n, idx:i, x:W/2+Math.cos(i)*120+(Math.random()-.5)*60,
  y:H/2+Math.sin(i)*120+(Math.random()-.5)*60, vx:0, vy:0,
  color: n.cluster? cidColor[n.cluster] : "#5b6168" }}));
const idx={{}}; nodes.forEach((n,i)=>idx[n.id]=i);
const edges=GRAPH.edges.map(e=>({{...e, s:idx[e.source], t:idx[e.target]}}));

const neighborIdx = {{}};
edges.forEach(e=>{{
  (neighborIdx[e.s] = neighborIdx[e.s] || new Set()).add(e.t);
  (neighborIdx[e.t] = neighborIdx[e.t] || new Set()).add(e.s);
}});

let view = {{x:0, y:0, k:1}};
function screenToWorld(mx,my){{ return [(mx-view.x)/view.k, (my-view.y)/view.k]; }}

let alpha = 1;
function step(){{
  if(alpha < 0.01) return;
  for(const n of nodes){{ n.vx*=0.82; n.vy*=0.82; }}
  for(let i=0;i<nodes.length;i++)for(let j=i+1;j<nodes.length;j++){{
    const a=nodes[i],b=nodes[j];let dx=a.x-b.x,dy=a.y-b.y;let d2=dx*dx+dy*dy+0.01;
    let f=alpha*2600/d2;let d=Math.sqrt(d2);dx/=d;dy/=d;
    a.vx+=dx*f;a.vy+=dy*f;b.vx-=dx*f;b.vy-=dy*f; }}
  for(const e of edges){{ const a=nodes[e.s],b=nodes[e.t];
    let dx=b.x-a.x,dy=b.y-a.y;let d=Math.sqrt(dx*dx+dy*dy)+.01;
    const rest=90-40*e.score; let f=alpha*(d-rest)*0.02*(0.4+e.score);
    dx/=d;dy/=d; a.vx+=dx*f;a.vy+=dy*f;b.vx-=dx*f;b.vy-=dy*f; }}
  for(const n of nodes){{ n.vx+=alpha*(W/2-n.x)*0.002; n.vy+=alpha*(H/2-n.y)*0.002;
    if(n!==drag){{ n.x+=n.vx; n.y+=n.vy; }} }}
  alpha *= 0.988;
}}
function lighten(hex, amt){{
  const n = parseInt(hex.replace('#',''),16);
  const r = Math.min(255, (n>>16) + Math.round(255*amt));
  const g = Math.min(255, ((n>>8)&0xff) + Math.round(255*amt));
  const b = Math.min(255, (n&0xff) + Math.round(255*amt));
  return `rgb(${{r}},${{g}},${{b}})`;
}}
function darken(hex, amt){{
  const n = parseInt(hex.replace('#',''),16);
  const r = Math.max(0, (n>>16) - Math.round(255*amt));
  const g = Math.max(0, ((n>>8)&0xff) - Math.round(255*amt));
  const b = Math.max(0, (n&0xff) - Math.round(255*amt));
  return `rgb(${{r}},${{g}},${{b}})`;
}}
function draw(){{
  ctx.clearRect(0,0,W,H);
  ctx.save();
  ctx.translate(view.x, view.y);
  ctx.scale(view.k, view.k);
  const hoverIdx = hoverNode? hoverNode.idx : null;
  const hoverSet = hoverIdx!=null ? (neighborIdx[hoverIdx]||new Set()) : null;
  for(const e of edges){{ const a=nodes[e.s],b=nodes[e.t];
    const connectedToHover = hoverIdx!=null && (e.s===hoverIdx || e.t===hoverIdx);
    let dim;
    if(hoverIdx!=null){{ dim = !connectedToHover; }}
    else{{ dim = selectedCluster && a.cluster!==selectedCluster && b.cluster!==selectedCluster; }}
    ctx.strokeStyle= e===hoverEdge? "#e0b64a" : connectedToHover? "#e0b64a" : dim? "rgba(120,132,146,.08)" : "rgba(120,132,146,.35)";
    ctx.lineWidth=(connectedToHover?1.7:1)*(0.5+3.2*e.score); ctx.beginPath();
    ctx.moveTo(a.x,a.y);ctx.lineTo(b.x,b.y);ctx.stroke(); }}
  for(const n of nodes){{
    let dim;
    if(hoverIdx!=null){{ dim = n.idx!==hoverIdx && !(hoverSet && hoverSet.has(n.idx)); }}
    else{{ dim = selectedCluster && n.cluster!==selectedCluster; }}
    ctx.globalAlpha = dim? 0.15 : 1;
    const r = n===hoverNode?13:10;
    const grad = ctx.createRadialGradient(n.x-r*0.4,n.y-r*0.4,0,n.x,n.y,r*1.05);
    grad.addColorStop(0, lighten(n.color,0.8));
    grad.addColorStop(0.35, n.color);
    grad.addColorStop(1, darken(n.color,0.4));
    ctx.beginPath();ctx.arc(n.x,n.y,r,0,7);
    ctx.fillStyle=grad;ctx.fill();
    ctx.lineWidth=1.3;ctx.strokeStyle="rgba(11,15,19,0.75)";ctx.stroke();
    ctx.fillStyle="#e6e9ec";ctx.font="700 9px ui-monospace,monospace";
    ctx.textAlign="center";ctx.textBaseline="middle";ctx.fillText(n.id,n.x,n.y-16);
    ctx.globalAlpha = 1; }}
  ctx.restore();
}}
function recenter(){{ for(const n of nodes){{
  n.x=W/2+(Math.random()-.5)*Math.min(W,400);
  n.y=H/2+(Math.random()-.5)*Math.min(H,400); n.vx=n.vy=0; }} }}
let drag=null,hoverNode=null,hoverEdge=null,selectedCluster=null,panning=false,panStart=null,panOrigin=null;
const tip=document.getElementById('tip');

function loop(){{ step();draw();requestAnimationFrame(loop); }}
loop();
[60,200,500].forEach(t=>setTimeout(()=>{{resize();}},t));
function at(wx,wy){{ for(const n of nodes){{ if((wx-n.x)**2+(wy-n.y)**2<170) return n; }} return null; }}

canvas.addEventListener('wheel',ev=>{{
  ev.preventDefault();
  const r=canvas.getBoundingClientRect();
  const mx=ev.clientX-r.left, my=ev.clientY-r.top;
  const [wx,wy]=screenToWorld(mx,my);
  const factor = ev.deltaY<0? 1.12 : 1/1.12;
  view.k = Math.min(4, Math.max(0.25, view.k*factor));
  view.x = mx - wx*view.k;
  view.y = my - wy*view.k;
}}, {{passive:false}});

canvas.addEventListener('mousemove',ev=>{{
  const r=canvas.getBoundingClientRect();const mx=ev.clientX-r.left,my=ev.clientY-r.top;
  if(panning){{ view.x=panOrigin.x+(ev.clientX-panStart.x); view.y=panOrigin.y+(ev.clientY-panStart.y); return; }}
  const [wx,wy]=screenToWorld(mx,my);
  if(drag){{drag.x=wx;drag.y=wy;drag.vx=drag.vy=0;alpha=1;return;}}
  hoverNode=at(wx,wy);
  if(hoverNode){{ const d=INC[hoverNode.id]||{{}};
    const nbrCount = (neighborIdx[hoverNode.idx]||new Set()).size;
    tip.innerHTML=`<h4>${{hoverNode.id}}</h4>`+
      `<div><span class="k">date</span> ${{d.date||'—'}} · <span class="k">loc</span> ${{d.location||'—'}}</div>`+
      `<div style="margin-top:4px"><span class="k">connects to</span> <code>${{nbrCount}}</code> incident${{nbrCount===1?'':'s'}}</div>`+
      (d.features&&d.features.length?`<div style="margin-top:4px"><span class="k">features</span> <code>${{d.features.join('</code> <code>')}}</code></div>`:'')+
      (d.persons&&d.persons.length?`<div><span class="k">persons</span> ${{d.persons.join(', ')}}</div>`:'')+
      (d.groups&&d.groups.length?`<div><span class="k">groups</span> ${{d.groups.join(', ')}}</div>`:'')+
      (d.phones&&d.phones.length?`<div><span class="k">phone</span> ${{d.phones.join(', ')}}</div>`:'');
    tip.style.display='block';tip.style.left=Math.min(mx+16,W-290)+'px';tip.style.top=(my+16)+'px';
    canvas.style.cursor='grab';return; }}
  hoverEdge=null;
  for(const e of edges){{ const a=nodes[e.s],b=nodes[e.t];
    const t=Math.max(0,Math.min(1,((wx-a.x)*(b.x-a.x)+(wy-a.y)*(b.y-a.y))/(((b.x-a.x)**2+(b.y-a.y)**2)||1)));
    const px=a.x+t*(b.x-a.x),py=a.y+t*(b.y-a.y);
    if((wx-px)**2+(wy-py)**2<25){{hoverEdge=e;break;}} }}
  if(hoverEdge){{ tip.innerHTML=`<h4>${{hoverEdge.source}} ↔ ${{hoverEdge.target}}</h4>`+
      `<div><span class="k">score</span> <code>${{hoverEdge.score}}</code></div>`+
      (hoverEdge.reasons||[]).map(x=>`<div>– ${{x}}</div>`).join('');
    tip.style.display='block';tip.style.left=Math.min(mx+16,W-290)+'px';tip.style.top=(my+16)+'px';
    canvas.style.cursor='default'; }}
  else {{ tip.style.display='none';canvas.style.cursor='default'; }}
}});
canvas.addEventListener('mousedown',ev=>{{
  const r=canvas.getBoundingClientRect();const mx=ev.clientX-r.left,my=ev.clientY-r.top;
  const [wx,wy]=screenToWorld(mx,my);
  const hit=at(wx,wy);
  if(hit){{ drag=hit; canvas.style.cursor='grabbing'; alpha=1; }}
  else {{ panning=true; panStart={{x:ev.clientX,y:ev.clientY}}; panOrigin={{x:view.x,y:view.y}}; canvas.style.cursor='grabbing'; }}
}});
window.addEventListener('mouseup',()=>{{drag=null;panning=false;}});

const cp=document.getElementById('clusters');
if(!CLUSTERS.length) cp.innerHTML='<div style="padding:0 16px;color:var(--muted);font-size:12px">No multi-incident clusters above threshold.</div>';
CLUSTERS.forEach(c=>{{
  const el=document.createElement('div');el.className='cluster';
  el.style.borderLeft='3px solid '+(cidColor[c.cluster_id]||'#5b6168');
  el.innerHTML=`<div><span class="cid">${{c.cluster_id}}</span><span class="sz">${{c.size}} incidents</span></div>`+
    `<div class="sig">${{(c.signature.length?c.signature:['(no dominant shared features)']).map(s=>'<span>'+s+'</span>').join('')}}</div>`+
    `<div class="mem">${{c.members.join(' · ')}}</div>`;
  el.onclick=()=>{{
    if(selectedCluster===c.cluster_id){{ selectedCluster=null; el.style.outline='none'; }}
    else{{
      document.querySelectorAll('.cluster').forEach(x=>x.style.outline='none');
      selectedCluster=c.cluster_id; el.style.outline='2px solid '+(cidColor[c.cluster_id]||'#5b6168');
      const m=new Set(c.members);
      nodes.forEach(n=>{{ if(m.has(n.id)){{ n.x=W/2+(Math.random()-.5)*160; n.y=H/2+(Math.random()-.5)*160; n.vx=n.vy=0; }} }});
      alpha=1;
    }}
  }};
  cp.appendChild(el);
}});
</script>
</body></html>"""


# --------------------------------------------------------------- brief ------
def console_brief(brief) -> str:
    L = []
    L.append("=" * 70)
    L.append(" PRE-ARRIVAL BRIEF")
    L.append("=" * 70)
    L.append(f" Location queried : {brief.location_query}")
    if brief.describe_query:
        L.append(f" Description      : {brief.describe_query}")
    if brief.responder_photo:
        L.append(f" Responder photo  : {brief.responder_photo}  (attached for specialist; not analysed)")
    L.append(f" Incidents on record in this area: {brief.n_in_area}")
    L.append("")
    L.append(" Object profile for this area (from the record):")
    if brief.object_profile:
        for t, c, rec in brief.object_profile:
            rec = f"most recent {rec}" if rec else "date n/k"
            L.append(f"   • {t:<20} seen in {c} incident(s)  ({rec})")
    else:
        L.append("   (no object-type reporting on record for this area)")
    L.append("")
    L.append(" Co-occurring device signature in this area:")
    L.append("   " + (", ".join(brief.area_signature) if brief.area_signature
                      else "(no dominant shared signature)"))
    if brief.matches:
        L.append("")
        L.append(" Closest past records to the description (retrieval, not identification):")
        for mrec in brief.matches:
            L.append(f"   [{mrec.score:>5}] {mrec.incident_id}  {mrec.location}  {mrec.date or ''}")
            L.append(f"           matches on : {', '.join(mrec.shared)}")
            L.append(f"           record obj : {', '.join(mrec.object_features)}")
            if mrec.photo:
                L.append(f"           ref photo  : {mrec.photo}")
    L.append("")
    L.append(" " + brief.note)
    return "\n".join(L)
