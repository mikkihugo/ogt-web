document.addEventListener('DOMContentLoaded', function(){
  var btn = document.getElementById('klarna-checkout-btn');
  var panel = document.getElementById('klarna-checkout-panel');
  if(!btn) return;

  btn.addEventListener('click', function(){
    btn.disabled = true;
    btn.textContent = 'Creating session...';

    // In Magento, call /klarna/checkout/createsession
    fetch('/klarna/checkout/createsession')
      .then(function(r){ return r.json(); })
      .then(function(data){
        btn.disabled = false;
        btn.textContent = 'Checkout with Klarna';
        if(data && data.success && data.session){
          panel.style.display = 'block';
          panel.innerHTML = '<pre style="white-space:pre-wrap">'+JSON.stringify(data.session, null, 2)+'</pre>';
        } else {
          panel.style.display = 'block';
          panel.innerHTML = '<div class="muted">Failed to create Klarna session. (This demo uses a stub.)</div>';
        }
      })
      .catch(function(){
        btn.disabled = false;
        btn.textContent = 'Checkout with Klarna';
        panel.style.display = 'block';
        panel.innerHTML = '<div class="muted">Error contacting Klarna demo endpoint.</div>';
      });
  });
});
