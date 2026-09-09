document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('form').forEach(form => {
    form.addEventListener('submit', event => {
      if (form.dataset.confirm && !window.confirm(form.dataset.confirm)) { event.preventDefault(); return; }
      if (!form.checkValidity()) return;
      form.setAttribute('aria-busy', 'true');
      const button = event.submitter;
      if (button && !button.name) { button.disabled = true; button.dataset.originalText = button.value || button.textContent; if (button.tagName === 'INPUT') button.value = '处理中…'; else button.textContent = '处理中…'; }
    });
  });
  document.querySelectorAll('[data-refresh]').forEach(el => {
    const delay = Number(el.dataset.refresh);
    if (Number.isFinite(delay) && delay >= 5) setTimeout(() => { if (!document.querySelector('form[aria-busy="true"]') && !document.querySelector('input:focus,select:focus,textarea:focus')) window.location.reload(); }, delay * 1000);
  });
});
