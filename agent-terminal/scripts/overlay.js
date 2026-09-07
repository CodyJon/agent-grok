(function () {
  if (window.__grokBar) return;
  window.__grokBar = true;

  function termPaste(text) {
    if (!text) return;
    if (window.term && typeof window.term.paste === "function") {
      window.term.paste(text);
      return;
    }
    var ta = document.querySelector("textarea.xterm-helper-textarea");
    if (!ta) return;
    ta.focus();
    try {
      document.execCommand("insertText", false, text);
    } catch (e) {
      ta.value = text;
      ta.dispatchEvent(new Event("input", { bubbles: true }));
    }
  }

  var bar = document.createElement("div");
  bar.id = "grok-bar";
  bar.innerHTML =
    '<button type="button" data-act="mic">Mic</button>' +
    '<button type="button" data-act="paste">Paste</button>' +
    '<button type="button" data-act="esc">Esc</button>' +
    '<button type="button" data-act="tab">Tab</button>' +
    '<button type="button" data-act="ctrlc">Ctrl-C</button>' +
    '<button type="button" data-act="enter">Enter</button>' +
    '<span id="grok-bar-status"></span>';

  var style = document.createElement("style");
  style.textContent =
    "#grok-bar{position:fixed;left:0;right:0;bottom:0;z-index:99999;" +
    "display:flex;gap:6px;align-items:center;flex-wrap:wrap;" +
    "padding:8px 10px calc(8px + env(safe-area-inset-bottom));" +
    "background:#16161e;border-top:1px solid #3b3b52;font:13px/1.2 system-ui,sans-serif}" +
    "#grok-bar button{background:#2a2a3d;color:#c0caf5;border:1px solid #414868;" +
    "border-radius:8px;padding:8px 10px;min-height:36px}" +
    "#grok-bar button.on{background:#7c3aed;border-color:#a78bfa;color:#fff}" +
    "#grok-bar-status{color:#9aa5ce;font-size:12px;flex:1;min-width:8em}" +
    ".xterm{padding-bottom:56px !important}";
  document.documentElement.appendChild(style);
  function mount() {
    if (!document.body) return;
    if (!document.getElementById("grok-bar")) document.body.appendChild(bar);
  }
  document.addEventListener("DOMContentLoaded", mount);
  mount();

  var status = function (t) {
    var el = document.getElementById("grok-bar-status");
    if (el) el.textContent = t || "";
  };

  var rec = null;
  var listening = false;
  var lastFinal = "";

  function stopMic() {
    listening = false;
    if (rec) {
      try { rec.stop(); } catch (e) {}
    }
    var btn = bar.querySelector('[data-act="mic"]');
    if (btn) btn.classList.remove("on");
  }

  function startMic() {
    var SR = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SR) {
      status("No speech API. Use Safari.");
      return;
    }
    rec = new SR();
    rec.lang = "en-CA";
    rec.continuous = false;
    rec.interimResults = true;
    rec.maxAlternatives = 1;
    lastFinal = "";
    rec.onresult = function (ev) {
      var text = "";
      var final = false;
      for (var i = ev.resultIndex; i < ev.results.length; i++) {
        text += ev.results[i][0].transcript;
        if (ev.results[i].isFinal) final = true;
      }
      text = (text || "").replace(/\s+/g, " ").trim();
      status(text || "Listening…");
      if (final && text && text !== lastFinal) {
        lastFinal = text;
        termPaste(text);
        stopMic();
        status("Inserted");
      }
    };
    rec.onerror = function (ev) {
      status(ev.error === "not-allowed" ? "Mic blocked. Open in a new Safari tab." : String(ev.error || "mic error"));
      stopMic();
    };
    rec.onend = function () {
      listening = false;
      var btn = bar.querySelector('[data-act="mic"]');
      if (btn) btn.classList.remove("on");
    };
    listening = true;
    bar.querySelector('[data-act="mic"]').classList.add("on");
    status("Listening…");
    try { rec.start(); } catch (e) {
      status("Mic failed");
      stopMic();
    }
  }

  bar.addEventListener("click", function (e) {
    var act = e.target && e.target.getAttribute && e.target.getAttribute("data-act");
    if (!act) return;
    e.preventDefault();
    e.stopPropagation();
    if (act === "mic") {
      if (listening) stopMic();
      else startMic();
      return;
    }
    if (act === "paste") {
      if (navigator.clipboard && navigator.clipboard.readText) {
        navigator.clipboard.readText().then(termPaste).catch(function () {
          var t = window.prompt("Paste into terminal");
          if (t) termPaste(t);
        });
      } else {
        var t2 = window.prompt("Paste into terminal");
        if (t2) termPaste(t2);
      }
      return;
    }
    if (act === "esc") termPaste("\u001b");
    if (act === "tab") termPaste("\t");
    if (act === "ctrlc") termPaste("\u0003");
    if (act === "enter") termPaste("\r");
  });
})();
