// VetDose Pro — interactive logic
let DB = {schema_version:1, actualizado:"2025-10-21", medicamentos:[]};
let CURRENT = null;

const schemaExample = {
  "schema_version": 1,
  "actualizado": "2025-10-21",
  "medicamentos": [
    {
      "id": "amoxicilina_clavulanato",
      "nombre": "Amoxicilina + Ácido clavulánico",
      "sinonimos": ["amoxiclav", "amoxi-clav"],
      "especies": ["perro","gato"],
      "vias": ["oral","inyectable"],
      "presentaciones": [
        {"via":"oral","descripcion":"Suspensión 50 mg/mL","concentracion_mg_ml":50},
        {"via":"oral","descripcion":"Comprimido 250 mg","concentracion_mg_unidad":250},
        {"via":"inyectable","descripcion":"Inyectable 140 mg/mL","concentracion_mg_ml":140}
      ],
      "dosis": {
        "perro": {"rango_mg_kg":[12.5,25], "intervalo_horas":12},
        "gato":  {"rango_mg_kg":[12.5,25], "intervalo_horas":12}
      },
      "max_dosis_total_mg": null,
      "notas": "Ajustar en IR; administrar con alimento."
    }
  ]
};

function $(q){return document.querySelector(q)}
function $all(q){return Array.from(document.querySelectorAll(q))}
function norm(s){return (s||'').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g,'')}

function setView(name){
  $all('.nav-btn').forEach(b=>b.classList.toggle('active', b.dataset.view===name));
  $all('.view').forEach(v=>v.classList.toggle('show', v.id==='view-'+name));
}

function toast(msg, ms=1800){
  const t = $('#toast');
  t.textContent = msg; t.classList.remove('hidden');
  setTimeout(()=>t.classList.add('hidden'), ms);
}

async function loadDefault(){
  try{
    const res = await fetch('medicamentos.json', {cache:'no-store'});
    DB = await res.json();
  }catch(e){
    console.warn('Fallo al cargar medicamentos.json, usando demo.');
    const res = await fetch('meds_demo.json', {cache:'no-store'});
    DB = await res.json();
  }
  updateDbDate();
  renderList();
  renderSchema();
}

function updateDbDate(){
  $('#dbDate').textContent = DB.actualizado || '—';
}

function renderSchema(){
  $('#schemaBlock').textContent = JSON.stringify(schemaExample, null, 2);
}

function search(q){
  const nq = norm(q);
  if(!nq) return [];
  return DB.medicamentos.filter(m=>{
    const hay = [m.nombre, ...(m.sinonimos||[])].map(norm).join(' ');
    return hay.includes(nq);
  }).slice(0, 100);
}

function renderList(){
  const lista = $('#lista'); lista.innerHTML = '';
  const q = $('#buscar').value;
  const resultados = q ? search(q) : DB.medicamentos.slice(0, 50);
  if(resultados.length===0){lista.innerHTML = '<div class="muted">Sin resultados</div>'; return;}
  resultados.forEach(m=>{
    const item = document.createElement('div');
    item.className = 'item';
    item.innerHTML = `
      <div class="name">${m.nombre}</div>
      <div class="badges">
        ${(m.vias||[]).map(v=>`<span class="badge">${v}</span>`).join('')}
        ${(m.especies||[]).map(v=>`<span class="badge">${v}</span>`).join('')}
      </div>`;
    item.addEventListener('click', ()=>selectMed(m));
    lista.appendChild(item);
  });
}

function selectMed(m){
  CURRENT = m;
  const card = $('#ficha');
  card.classList.remove('empty');
  const especies = ['perro','gato'];
  const eSel = $('#especie').value;
  const dInfo = (m.dosis||{})[eSel];

  const viasOptions = (m.vias||[]).map(v=>`<option>${v}</option>`).join('');
  const pres = (m.presentaciones||[]).filter(p=>p.via===(m.vias?.[0]||''));
  const presOptions = pres.map((p,i)=>{
    const conc = p.concentracion_mg_ml ? `${p.concentracion_mg_ml} mg/mL` :
                p.concentracion_mg_unidad ? `${p.concentracion_mg_unidad} mg/unid.` : '—';
    return `<option value="${i}">${p.descripcion} — ${conc}</option>`
  }).join('');

  const rango = dInfo?.rango_mg_kg ? `Rango sugerido: ${dInfo.rango_mg_kg[0]}–${dInfo.rango_mg_kg[1]} mg/kg` : '';

  card.innerHTML = `
    <div class="card-body">
      <h3>${m.nombre}</h3>
      <div class="muted">${m.notas || ''}</div>

      <div class="grid-3" style="margin-top:10px">
        <label>Vía
          <select id="viaSel">${viasOptions}</select>
        </label>
        <label>Presentación
          <select id="presSel">${presOptions}</select>
        </label>
        <label>Dosis (mg/kg)
          <div class="input-suffix">
            <input id="dosis" type="number" step="0.01" />
            <span>mg/kg</span>
          </div>
          <small class="muted">${rango}</small>
        </label>
      </div>

      <div class="grid-3">
        <label>Intervalo
          <div class="input-suffix">
            <input id="intervalo" type="number" step="1" />
            <span>h</span>
          </div>
        </label>
        <label>Peso
          <div class="input-suffix">
            <input id="pesoForm" type="number" step="0.01" />
            <span>kg</span>
          </div>
        </label>
        <div class="actions">
          <button id="btnCalc" class="primary">Calcular</button>
        </div>
      </div>

      <div class="kpis">
        <div class="kpi">
          <div class="label">Dosis total</div>
          <div class="value" id="outMg">—</div>
          <div class="sub">mg</div>
        </div>
        <div class="kpi">
          <div class="label">Volumen</div>
          <div class="value" id="outMl">—</div>
          <div class="sub">mL</div>
        </div>
        <div class="kpi">
          <div class="label">Pauta</div>
          <div class="value" id="outPauta">—</div>
          <div class="sub">cada X horas</div>
        </div>
      </div>
    </div>
  `;

  const viaSel = $('#viaSel');
  const presSel = $('#presSel');

  viaSel.addEventListener('change', ()=>{
    const pres2 = (m.presentaciones||[]).filter(p=>p.via===viaSel.value);
    presSel.innerHTML = pres2.map((p,i)=>{
      const conc = p.concentracion_mg_ml ? `${p.concentracion_mg_ml} mg/mL` :
                  p.concentracion_mg_unidad ? `${p.concentracion_mg_unidad} mg/unid.` : '—';
      return `<option value="${i}">${p.descripcion} — ${conc}</option>`
    }).join('');
  });

  if(dInfo && dInfo.rango_mg_kg){
    const avg = (dInfo.rango_mg_kg[0] + dInfo.rango_mg_kg[1]) / 2;
    $('#dosis').value = avg.toFixed(2);
    $('#intervalo').value = dInfo.intervalo_horas;
  }

  $('#pesoForm').value = $('#peso').value || '';

  $('#btnCalc').addEventListener('click', ()=>{
    const peso = parseFloat($('#pesoForm').value);
    const dosis = parseFloat($('#dosis').value);
    const intv = parseInt($('#intervalo').value, 10);
    if(!(peso>0 && dosis>0 && Number.isFinite(intv))){ toast('Completa peso, dosis e intervalo válidos'); return; }
    const via = viaSel.value;
    const presL = (m.presentaciones||[]).filter(p=>p.via===via);
    const p = presL[parseInt(presSel.value,10)];

    const totalMg = peso * dosis;
    let ml = null;
    if(p && p.concentracion_mg_ml) ml = totalMg / p.concentracion_mg_ml;

    $('#outMg').textContent = totalMg.toFixed(2);
    $('#outMl').textContent = ml!=null ? ml.toFixed(2) : '—';
    $('#outPauta').textContent = `cada ${intv} h`;

    if(m.max_dosis_total_mg && totalMg > m.max_dosis_total_mg){
      toast(`⚠️ Excede dosis total máxima (${m.max_dosis_total_mg} mg).`, 2800);
    }
  });
}

function renderTable(){
  const filtroVia = $('#filtroVia').value;
  const filtroEspecie = $('#filtroEspecie').value;

  const list = DB.medicamentos.filter(m=>{
    const okVia = !filtroVia or (m.vias||[]).includes(filtroVia);
    const okEsp = !filtroEspecie or (m.especies||[]).includes(filtroEspecie);
    return okVia && okEsp;
  }).slice(0, 300);

  const thead = `<div class="thead"><div>Nombre</div><div>Vías</div><div>Especies</div><div>Rango mg/kg</div></div>`;
  const rows = list.map(m=>{
    const per = m.dosis?.perro?.rango_mg_kg;
    const gat = m.dosis?.gato?.rango_mg_kg;
    const rango = [per?`Perro ${per[0]}–${per[1]}`:null, gat?`Gato ${gat[0]}–${gat[1]}`:null].filter(Boolean).join(' • ');
    return `<div class="row">
      <div>${m.nombre}</div>
      <div>${(m.vias||[]).join(', ')}</div>
      <div>${(m.especies||[]).join(', ')}</div>
      <div>${rango||'—'}</div>
    </div>`;
  }).join('');

  $('#tabla').innerHTML = thead + rows;
}

function bindEvents(){
  $('#buscar').addEventListener('input', ()=>{ renderList(); });
  $('#btnLimpiar').addEventListener('click', ()=>{ $('#buscar').value=''; renderList(); CURRENT=null; $('#ficha').classList.add('empty'); $('#ficha').innerHTML='<div class="empty-msg">Busca y selecciona un medicamento</div>'; });
  $('#especie').addEventListener('change', ()=>{ if(CURRENT) selectMed(CURRENT); });
  $all('.nav-btn').forEach(btn=>btn.addEventListener('click', ()=>setView(btn.dataset.view)));
  $('#filtroVia').addEventListener('change', renderTable);
  $('#filtroEspecie').addEventListener('change', renderTable);

  // custom file loader
  $('#fileInput').addEventListener('change', async (e)=>{
    const f = e.target.files?.[0];
    if(!f) return;
    try{
      const txt = await f.text();
      const json = JSON.parse(txt);
      if(!json.medicamentos) throw new Error('Estructura inválida.');
      DB = json; updateDbDate(); renderList(); renderTable(); toast('Base cargada correctamente');
    }catch(err){
      console.error(err); toast('Error al cargar JSON', 2500);
    }
  });
}

document.addEventListener('DOMContentLoaded', async()=>{
  bindEvents();
  await loadDefault();
  renderTable();
});
