function switchTab(name){
  document.querySelectorAll('.tab-panel').forEach(p=>p.classList.remove('active'));
  document.querySelectorAll('.tab').forEach(b=>b.classList.remove('active'));
  document.querySelectorAll('.nav-icon').forEach(i=>i.classList.remove('active'));
  const panel=document.getElementById('tab-'+name);
  if(panel)panel.classList.add('active');
  const topTab=document.querySelector('.tab[data-tab="'+name+'"]');
  if(topTab)topTab.classList.add('active');
  const sideTab=document.querySelector('.nav-icon[data-tab="'+name+'"]');
  if(sideTab)sideTab.classList.add('active');
}

document.getElementById('csv-input').addEventListener('change',function(){
  document.getElementById('file-label').textContent=this.files[0]?.name||'Choose CSV file…';
});

function analyzeFile(){
  const fd=new FormData();
  const f=document.getElementById('csv-input').files[0];
  if(f)fd.append('csvfile',f);
  runAnalysis('/analyze',{method:'POST',body:fd});
}

function loadSample(){runAnalysis('/sample',{method:'GET'});}

function runAnalysis(url,opts){
  document.getElementById('spinner').style.display='block';
  document.getElementById('dashboard').style.display='none';
  document.getElementById('analyze-btn').disabled=true;
  fetch(url,opts)
    .then(r=>r.json())
    .then(data=>{if(data.error){alert('Error: '+data.error);return;}renderDashboard(data);})
    .catch(e=>alert('Request failed: '+e))
    .finally(()=>{document.getElementById('spinner').style.display='none';document.getElementById('analyze-btn').disabled=false;});
}

function esc(v){
  return String(v).replaceAll('&','&amp;').replaceAll('<','&lt;')
    .replaceAll('>','&gt;').replaceAll('"','&quot;').replaceAll("'",'&#39;');
}

function renderDashboard(d){
  renderKPIs(d);
  renderOverview(d.overview);
  renderStats(d.stats,d.numeric||[],d.cat_stats||d.text_stats||{},d.categorical||d.text||[]);
  renderCorrelation(d.cor_rows, d.cat_cor_rows || [], d.mixed_cor_rows || []);
  renderCharts(d.plots);
  document.getElementById('dashboard').style.display='block';
}

function renderKPIs(d){
  const catCount=(d.categorical||d.text||[]).length;
  const totalMissing=d.overview.reduce((s,r)=>s+r.missing,0);
  const kpis=[
    {label:'Rows',value:d.rows.toLocaleString(),sub:'total records'},
    {label:'Columns',value:d.cols,sub:'all types'},
    {label:'Numeric Cols',value:(d.numeric||[]).length,sub:'analyzed'},
    {label:'Categorical',value:catCount,sub:'analyzed'},
    {label:'Missing Values',value:totalMissing,sub:'across dataset'},
    {label:'Dataset',value:d.filename,sub:'source file',cardClass:'dataset',valueClass:'kpi-value-file'},
  ];
  document.getElementById('kpi-row').innerHTML=kpis.map(k=>`
    <div class="kpi-card ${k.cardClass||''}">
      <div class="kpi-label">${k.label}</div>
      <div class="kpi-value ${k.valueClass||''}" title="${esc(k.value)}">${k.value}</div>
      <div class="kpi-sub">${k.sub}</div>
    </div>`).join('');
}

function renderOverview(rows){
  document.getElementById('col-count-badge').textContent=rows.length+' columns';
  document.getElementById('overview-body').innerHTML=rows.map(r=>{
    const badge=r.missing===0
      ?`<span class="badge badge-green">Clean</span>`
      :r.pct>20
        ?`<span class="badge badge-red">${r.pct}% missing</span>`
        :`<span class="badge badge-amber">${r.pct}% missing</span>`;
    return`<tr>
      <td><strong style="color:var(--text)">${esc(r.name)}</strong></td>
      <td><code class="type">${esc(r.type)}</code></td>
      <td>${r.missing}</td>
      <td style="color:${r.pct>20?'var(--red)':r.pct>0?'var(--amber)':'var(--text3)'}">${r.pct}%</td>
      <td>${badge}</td>
    </tr>`;
  }).join('');
}

function renderStats(stats,numeric,catStats,catCols){
  const cards=[];
  const labels={n:'Count',mean:'Mean',std:'Std Dev',min:'Min',q1:'Q1 (25th)',median:'Median',q3:'Q3 (75th)',max:'Max',iqr:'IQR',skew:'Skewness',kurt:'Kurtosis',cv:'CV (%)'};

  numeric.forEach(col=>{
    const s=stats[col];if(!s)return;
    const rows=Object.entries(labels).map(([k,label])=>
      `<div class="stat-pair"><span class="sk">${label}</span><span class="sv">${s[k]}</span></div>`
    ).join('');
    cards.push(`<div class="col-card">
      <div class="col-card-header">
        <span class="col-card-name">📊 ${esc(col)}</span>
        <span class="col-card-type">numeric · n=${s.n}</span>
      </div>${rows}</div>`);
  });

  catCols.forEach(col=>{
    const s=catStats[col];if(!s)return;
    const base=[['Count',s.n],['Unique',s.unique],['Uniqueness',`${s.unique_pct}%`],['Mode',esc(s.mode)]]
      .map(([l,v])=>`<div class="stat-pair"><span class="sk">${l}</span><span class="sv">${v}</span></div>`).join('');
    const top=(s.top||[]).map(t=>
      `<div class="stat-pair">
        <span class="sk" style="max-width:160px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${esc(t.value)}</span>
        <span class="sv">${t.count} <span style="color:var(--text3);font-size:.7rem">(${t.pct}%)</span></span>
      </div>`).join('');
    cards.push(`<div class="col-card">
      <div class="col-card-header">
        <span class="col-card-name">🏷 ${esc(col)}</span>
        <span class="col-card-type">categorical · n=${s.n}</span>
      </div>${base}
      <div style="margin:.7rem 0 .3rem;font-size:.68rem;color:var(--text3);text-transform:uppercase;letter-spacing:.5px;font-weight:600">Top values</div>
      ${top}</div>`);
  });

  document.getElementById('stats-grid').innerHTML=cards.length
    ?cards.join('')
    :'<div class="empty">No numeric or categorical columns found.</div>';
}

function renderCorrelation(rows, catRows, mixedRows){
  if(!rows||!rows.length){
    document.getElementById('cor-body').innerHTML=
      '<tr><td colspan="6" style="text-align:center;color:var(--text3);padding:2rem">Need at least 2 non-categorical numeric columns.</td></tr>';
  } else {
    document.getElementById('cor-body').innerHTML=rows.map(r=>{
      const bar=Math.abs(r.r);
      const color=r.r>=0?'var(--teal)':'var(--red)';
      const sc=r.strength==='Strong'?'str-strong':r.strength==='Moderate'?'str-moderate':'str-weak';
      const dc=r.dir==='Positive'?'dir-pos':r.dir==='Negative'?'dir-neg':'';
      return`<tr>
      <td style="color:var(--text);font-weight:500">${esc(r.a)}</td>
      <td style="color:var(--text);font-weight:500">${esc(r.b)}</td>
      <td>
        <div class="cor-bar-wrap">
          <div class="cor-bar-bg"><div class="cor-bar-fill" style="width:${bar*100}%;background:${color}"></div></div>
          <span class="cor-val" style="color:${color}">${r.r}</span>
        </div>
      </td>
      <td>${r.n??'-'}</td>
      <td><span class="${sc}">${r.strength}</span></td>
      <td><span class="${dc}">${r.dir}</span></td>
    </tr>`;
    }).join('');
  }

  if(!catRows||!catRows.length){
    document.getElementById('cat-cor-body').innerHTML=
      '<tr><td colspan="5" style="text-align:center;color:var(--text3);padding:2rem">Need at least 2 categorical columns.</td></tr>';
  } else {
    document.getElementById('cat-cor-body').innerHTML=catRows.map(r=>{
      const bar=Math.abs(r.v);
      const color='var(--accent)';
      const sc=r.strength==='Strong'?'str-strong':r.strength==='Moderate'?'str-moderate':'str-weak';
      return`<tr>
      <td style="color:var(--text);font-weight:500">${esc(r.a)}</td>
      <td style="color:var(--text);font-weight:500">${esc(r.b)}</td>
      <td>
        <div class="cor-bar-wrap">
          <div class="cor-bar-bg"><div class="cor-bar-fill" style="width:${bar*100}%;background:${color}"></div></div>
          <span class="cor-val" style="color:${color}">${r.v}</span>
        </div>
      </td>
      <td>${r.n??'-'}</td>
      <td><span class="${sc}">${r.strength}</span></td>
    </tr>`;
    }).join('');
  }

  if(!mixedRows||!mixedRows.length){
    document.getElementById('mixed-cor-body').innerHTML=
      '<tr><td colspan="6" style="text-align:center;color:var(--text3);padding:2rem">Need at least 1 categorical and 1 non-categorical numeric column.</td></tr>';
  } else {
    document.getElementById('mixed-cor-body').innerHTML=mixedRows.map(r=>{
      const bar=Math.abs(r.eta);
      const color='var(--teal)';
      const sc=r.strength==='Strong'?'str-strong':r.strength==='Moderate'?'str-moderate':'str-weak';
      return`<tr>
      <td style="color:var(--text);font-weight:500">${esc(r.cat)}</td>
      <td style="color:var(--text);font-weight:500">${esc(r.num)}</td>
      <td>
        <div class="cor-bar-wrap">
          <div class="cor-bar-bg"><div class="cor-bar-fill" style="width:${bar*100}%;background:${color}"></div></div>
          <span class="cor-val" style="color:${color}">${r.eta}</span>
        </div>
      </td>
      <td>${r.eta2}</td>
      <td>${r.n??'-'}</td>
      <td><span class="${sc}">${r.strength}</span></td>
    </tr>`;
    }).join('');
  }
}

function renderCharts(plots){
  const titles={
    boxplot:'📦 Box Plot — All Numeric Columns',
    heatmap:'🌡 Correlation Heatmap',
    scatter:'🔵 Scatter Matrix (Pairs Plot)',
  };
  const entries=Object.entries(plots||{});
  if(!entries.length){
    document.getElementById('plot-grid').innerHTML='<div class="empty">No plots available.</div>';
    return;
  }
  const hists=entries.filter(([k])=>k.startsWith('hist_'));
  const cats=entries.filter(([k])=>k.startsWith('cat_')||k.startsWith('text_'));
  const rest=entries.filter(([k])=>!k.startsWith('hist_')&&!k.startsWith('cat_')&&!k.startsWith('text_'));
  const makeCard=([key,src])=>{
    const hc=key.startsWith('hist_')?key.replace('hist_',''):null;
    const cc=key.startsWith('cat_')?key.replace('cat_',''):key.startsWith('text_')?key.replace('text_',''):null;
    const title=hc?`📊 Histogram — ${esc(hc)}`:cc?`🏷 Category Frequency — ${esc(cc)}`:(titles[key]||key);
    return`<div class="plot-card">
      <div class="plot-card-header"><div class="plot-dot"></div>${title}</div>
      <img src="${src}" alt="${title}" loading="lazy"/>
    </div>`;
  };
  document.getElementById('plot-grid').innerHTML=[...hists,...cats,...rest].map(makeCard).join('');
}
