// js/create-event.js
// Create event form with live preview

import { get, post, clearCache } from './api.js';
import { showToast, escapeHtml, escapeHtmlAttr, $ } from './ui.js';

// ============================================
// INITIALIZATION
// ============================================

export function setupCreateEventUI() {
  const form = $('#create-event-form');
  if (!form) return;
  
  // Get preselected market from URL
  const urlParams = new URLSearchParams(window.location.search);
  const preselectedMarket = parseInt(urlParams.get('market_id') || '0', 10);
  
  // Populate markets dropdown
  loadMarketsDropdown(preselectedMarket);
  
  // Setup type toggle
  setupTypeToggle();
  
  // Setup binary sliders
  setupBinarySliders();
  
  // Setup multiple choice outcomes
  setupMultipleOutcomes();
  
  // Setup live preview
  setupLivePreview();
  
  // Setup form submission
  setupFormSubmission();
}

// ============================================
// MARKETS DROPDOWN
// ============================================

async function loadMarketsDropdown(preselectedId = 0) {
  const select = $('#event-market');
  if (!select) return;
  
  const result = await get('markets.php', { useCache: true });
  
  if (!result.ok) {
    const opt = document.createElement('option');
    opt.value = '';
    opt.textContent = 'Could not load markets';
    select.appendChild(opt);
    return;
  }
  
  const markets = result.data.markets || [];
  
  if (markets.length === 0) {
    const opt = document.createElement('option');
    opt.value = '';
    opt.textContent = 'No markets - create one first';
    select.appendChild(opt);
    return;
  }
  
  for (const market of markets) {
    const opt = document.createElement('option');
    opt.value = market.id;
    opt.textContent = market.name;
    
    if (preselectedId && market.id === preselectedId) {
      opt.selected = true;
    }
    
    select.appendChild(opt);
  }
}

// ============================================
// TYPE TOGGLE
// ============================================

function setupTypeToggle() {
  const toggle = $('#event-type-toggle');
  const typeInput = $('#event-type');
  const binaryBox = $('#binary-settings');
  const multipleBox = $('#multiple-settings');
  
  if (!toggle) return;
  
  toggle.querySelectorAll('button').forEach(btn => {
    btn.addEventListener('click', () => {
      toggle.querySelectorAll('button').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      
      const type = btn.dataset.type;
      if (typeInput) typeInput.value = type;
      
      if (type === 'binary') {
        if (binaryBox) binaryBox.style.display = '';
        if (multipleBox) multipleBox.style.display = 'none';
      } else {
        if (binaryBox) binaryBox.style.display = 'none';
        if (multipleBox) multipleBox.style.display = '';
      }
      
      // Update preview
      updatePreview();
    });
  });
}

// ============================================
// BINARY SLIDERS
// ============================================

function setupBinarySliders() {
  const yesInput = $('#event-yes-percent');
  const noInput = $('#event-no-percent');
  
  if (!yesInput || !noInput) return;
  
  yesInput.addEventListener('input', () => {
    let v = parseInt(yesInput.value || '50', 10);
    if (isNaN(v)) v = 50;
    v = Math.max(1, Math.min(99, v));
    yesInput.value = String(v);
    noInput.value = String(100 - v);
    updatePreview();
  });
  
  noInput.addEventListener('input', () => {
    let v = parseInt(noInput.value || '50', 10);
    if (isNaN(v)) v = 50;
    v = Math.max(1, Math.min(99, v));
    noInput.value = String(v);
    yesInput.value = String(100 - v);
    updatePreview();
  });
}

// ============================================
// MULTIPLE CHOICE OUTCOMES
// ============================================

function setupMultipleOutcomes() {
  const container = $('#multiple-outcomes');
  const addBtn = $('#add-outcome');
  
  if (!container || !addBtn) return;
  
  function addOutcomeRow(label = '', prob = '') {
    const row = document.createElement('div');
    row.className = 'multiple-outcome-row';
    row.innerHTML = `
      <input type="text" class="multi-label" placeholder="Outcome label" value="${escapeHtmlAttr(label)}">
      <input type="number" class="multi-prob" min="1" max="99" placeholder="%" value="${escapeHtmlAttr(prob)}">
      <button type="button" class="remove-outcome" aria-label="Remove">×</button>
    `;
    
    row.querySelector('.remove-outcome').addEventListener('click', () => {
      row.remove();
      updatePreview();
    });
    
    row.querySelectorAll('input').forEach(input => {
      input.addEventListener('input', updatePreview);
    });
    
    container.appendChild(row);
    updatePreview();
  }
  
  addBtn.addEventListener('click', () => addOutcomeRow());
  
  // Start with default rows
  addOutcomeRow('Option A', '50');
  addOutcomeRow('Option B', '50');
}

// ============================================
// LIVE PREVIEW
// ============================================

function setupLivePreview() {
  const titleInput = $('#event-title');
  
  titleInput?.addEventListener('input', updatePreview);
  
  // Initial preview
  updatePreview();
}

function updatePreview() {
  const previewEl = $('#create-event-preview-card');
  if (!previewEl) return;
  
  const title = $('#event-title')?.value.trim() || 'Your question here...';
  const type = $('#event-type')?.value || 'binary';
  const yesPct = parseInt($('#event-yes-percent')?.value || '50', 10);
  const noPct = 100 - yesPct;
  
  if (type === 'binary') {
    previewEl.innerHTML = `
      <div class="market-header">
        <div class="market-creator">
          <div class="creator-avatar">🎯</div>
          <div>
            <div class="creator-name">Preview</div>
            <div class="market-meta">Binary event</div>
          </div>
        </div>
      </div>
      <h3 class="market-question">${escapeHtml(title)}</h3>
      <div class="market-odds">
        <div class="odds-bar">
          <div class="odds-fill yes" style="width:${yesPct}%"></div>
          <div class="odds-fill no" style="width:${noPct}%"></div>
        </div>
        <div class="odds-labels">
          <span class="odds-label-yes">YES ${yesPct}¢</span>
          <span class="odds-label-no">NO ${noPct}¢</span>
        </div>
      </div>
    `;
  } else {
    const rows = document.querySelectorAll('#multiple-outcomes .multiple-outcome-row');
    let outcomesHtml = '';
    
    rows.forEach(row => {
      const label = row.querySelector('.multi-label')?.value.trim() || 'Option';
      const prob = row.querySelector('.multi-prob')?.value || '?';
      outcomesHtml += `
        <div class="outcome-pill preview">
          <span class="outcome-label">${escapeHtml(label)}</span>
          <span class="outcome-prob">${prob}%</span>
        </div>
      `;
    });
    
    previewEl.innerHTML = `
      <div class="market-header">
        <div class="market-creator">
          <div class="creator-avatar">🎯</div>
          <div>
            <div class="creator-name">Preview</div>
            <div class="market-meta">Multiple choice</div>
          </div>
        </div>
      </div>
      <h3 class="market-question">${escapeHtml(title)}</h3>
      <div class="outcomes-pills" style="margin-top:1rem;">${outcomesHtml}</div>
    `;
  }
}

// ============================================
// FORM SUBMISSION
// ============================================

function setupFormSubmission() {
  const form = $('#create-event-form');
  const errorEl = $('#create-event-error');
  const okEl = $('#create-event-success');
  
  if (!form) return;
  
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    
    if (errorEl) errorEl.style.display = 'none';
    if (okEl) okEl.style.display = 'none';
    
    const formData = new FormData(form);
    const market_id = parseInt(formData.get('market_id'), 10);
    const title = formData.get('title')?.toString().trim() || '';
    const description = formData.get('description')?.toString().trim() || '';
    const event_type = formData.get('event_type')?.toString() || 'binary';
    const closes_at = formData.get('closes_at')?.toString() || '';
    
    if (!market_id || !title || !closes_at) {
      if (errorEl) {
        errorEl.textContent = 'Please fill in all required fields.';
        errorEl.style.display = 'block';
      }
      return;
    }
    
    const payload = { market_id, title, description, event_type, closes_at };
    
    if (event_type === 'binary') {
      const yesPct = parseInt($('#event-yes-percent')?.value || '50', 10);
      payload.yes_percent = yesPct;
    } else {
      const rows = document.querySelectorAll('#multiple-outcomes .multiple-outcome-row');
      const outcomes = [];
      
      rows.forEach(row => {
        const label = row.querySelector('.multi-label')?.value.trim();
        const probability = parseInt(row.querySelector('.multi-prob')?.value || '0', 10);
        if (label && probability > 0) {
          outcomes.push({ label, probability });
        }
      });
      
      if (outcomes.length < 2) {
        if (errorEl) {
          errorEl.textContent = 'Please add at least 2 outcomes.';
          errorEl.style.display = 'block';
        }
        return;
      }
      
      payload.outcomes = outcomes;
    }
    
    const submitBtn = form.querySelector('button[type="submit"]');
    submitBtn.disabled = true;
    submitBtn.textContent = 'Creating...';
    
    const result = await post('events.php', payload);
    
    if (!result.ok) {
      if (errorEl) {
        errorEl.textContent = result.error || 'Could not create event.';
        errorEl.style.display = 'block';
      }
      submitBtn.disabled = false;
      submitBtn.textContent = 'Create Event';
      return;
    }
    
    if (okEl) {
      okEl.textContent = 'Event created! Redirecting...';
      okEl.style.display = 'block';
    }
    
    clearCache('events');
    clearCache('markets');
    
    if (result.data.id) {
      setTimeout(() => {
        window.location.href = `event.php?id=${result.data.id}`;
      }, 800);
    }
  });
}

export default {
  setupCreateEventUI,
};

