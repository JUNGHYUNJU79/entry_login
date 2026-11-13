(function () {
  const STUDENTS = [
    { num: 1, id: "wol0161008", pw: "a1234567" },
    { num: 2, id: "wol0298243", pw: "a1234567" },
    { num: 3, id: "wol0311539", pw: "a1234567" },
    { num: 4, id: "wol0419179", pw: "a1234567" },
    { num: 5, id: "wol0526983", pw: "a1234567" },
    { num: 6, id: "wol0627207", pw: "a1234567" },
    { num: 7, id: "wol078147", pw: "a1234567" },
    { num: 8, id: "wol0885499", pw: "a1234567" },
    { num: 9, id: "wol0986416", pw: "a1234567" },
    { num: 10, id: "wol1026316", pw: "a1234567" },
    { num: 11, id: "wol1111588", pw: "a1234567" },
    { num: 12, id: "wol1247264", pw: "a1234567" },
    { num: 13, id: "wol1379178", pw: "a1234567" },
    { num: 14, id: "wol1452218", pw: "a1234567" },
    { num: 15, id: "wol1575234", pw: "a1234567" }
  ];

  // 포털(index.html)에서 번호를 들고 들어온 경우,
  // 아이디/비밀번호를 채운 뒤 로그인 버튼까지 자동으로 누를지 여부 (false면 입력만 하고 멈춤)
  const AUTO_SUBMIT = true;
  const URL_PARAM = "hawon";
  const STORAGE_KEY = "hawon_pending_num";

  // ---------- URL(?hawon=3 또는 #hawon=3)에서 학생 번호 읽기 ----------
  function readNumFromUrl() {
    let num = null;
    try {
      const sp = new URLSearchParams(location.search);
      if (sp.has(URL_PARAM)) num = parseInt(sp.get(URL_PARAM), 10);
    } catch (e) {}
    if (!num && location.hash) {
      const m = location.hash.match(new RegExp(URL_PARAM + "=(\\d+)"));
      if (m) num = parseInt(m[1], 10);
    }
    return Number.isInteger(num) && num >= 1 && num <= STUDENTS.length ? num : null;
  }

  // URL에 번호가 있으면 sessionStorage에 보관 (엔트리가 주소를 다시 쓰더라도 잃어버리지 않도록)
  const urlNum = readNumFromUrl();
  if (urlNum) {
    try { sessionStorage.setItem(STORAGE_KEY, String(urlNum)); } catch (e) {}
    // 주소창에서 번호 흔적 제거 (새로고침 시 반복 로그인 방지)
    try {
      const clean = new URL(location.href);
      clean.searchParams.delete(URL_PARAM);
      clean.hash = clean.hash.replace(new RegExp("#?" + URL_PARAM + "=\\d+"), "");
      history.replaceState(history.state, "", clean.pathname + clean.search + clean.hash);
    } catch (e) {}
  }

  function takePendingNum() {
    let num = null;
    try {
      const v = sessionStorage.getItem(STORAGE_KEY);
      if (v) {
        num = parseInt(v, 10);
        sessionStorage.removeItem(STORAGE_KEY);
      }
    } catch (e) {}
    return Number.isInteger(num) && num >= 1 && num <= STUDENTS.length ? num : null;
  }

  // ---------- 입력값 주입 (React 상태까지 반영) ----------
  function setInputValue(input, value) {
    if (!input) return;
    const nativeSetter = Object.getOwnPropertyDescriptor(
      window.HTMLInputElement.prototype,
      "value"
    )?.set;
    if (nativeSetter) {
      nativeSetter.call(input, value);
    } else {
      input.value = value;
    }
    input.dispatchEvent(new Event("input", { bubbles: true }));
    input.dispatchEvent(new Event("change", { bubbles: true }));
  }

  function fillCredentials(student) {
    const userInput = document.getElementById("username");
    const passInput = document.getElementById("password");
    if (!userInput || !passInput) return false;

    setInputValue(userInput, student.id);
    setInputValue(passInput, student.pw);

    const autoLogin = document.getElementById("AutoLogin");
    if (autoLogin && !autoLogin.checked) {
      autoLogin.click();
    }
    return true;
  }

  function clickLoginButton() {
    const loginBtn =
      document.querySelector('[data-testid="signin"]') ||
      document.getElementById("signin") ||
      document.querySelector(".entry_btn button") ||
      document.querySelector(".entry_btn");
    if (loginBtn) {
      loginBtn.click();
      return true;
    }
    return false;
  }

  function handleStudentLogin(student, btn, statusEl, submit) {
    if (!fillCredentials(student)) {
      statusEl.textContent = "⚠️ 로그인 입력창을 찾을 수 없습니다. 페이지를 새로고침해 주세요.";
      statusEl.style.color = "#e74c3c";
      return;
    }

    btn.classList.add("loading");
    statusEl.style.color = "#00a832";
    statusEl.textContent = "🚀 [" + student.num + "번] " + student.id + " 계정으로 로그인 중...";

    if (!submit) {
      btn.classList.remove("loading");
      btn.classList.add("success");
      statusEl.textContent = "✅ [" + student.num + "번] 아이디/비밀번호가 입력되었습니다. 로그인 버튼을 눌러주세요.";
      return;
    }

    // React 상태 반영 대기 후 로그인 버튼 클릭
    setTimeout(() => {
      if (clickLoginButton()) {
        btn.classList.remove("loading");
        btn.classList.add("success");
        statusEl.textContent = "✅ [" + student.num + "번] 로그인 완료! 화면이 이동합니다...";
      } else {
        btn.classList.remove("loading");
        statusEl.textContent = "⚠️ 로그인 버튼을 찾지 못했습니다. 직접 로그인 버튼을 눌러주세요.";
        statusEl.style.color = "#e74c3c";
      }
    }, 200);
  }

  // ---------- 번호판 패널 삽입 ----------
  function injectPanel() {
    if (document.getElementById("hawon-entry-panel")) return;

    const userInput = document.getElementById("username");
    if (!userInput) return;

    let targetContainer = userInput.closest("form") || userInput.closest("div[class*='el']");
    if (!targetContainer) {
      targetContainer = userInput.parentElement && userInput.parentElement.parentElement;
    }
    if (!targetContainer || !targetContainer.parentNode) return;

    const panel = document.createElement("div");
    panel.id = "hawon-entry-panel";

    panel.innerHTML =
      '<div class="hawon-header">' +
        '<h3 class="hawon-title">' +
          '<span>🏫 하원초등학교 6학년</span>' +
          '<span class="hawon-badge">원클릭 로그인</span>' +
        '</h3>' +
        '<p class="hawon-desc">자기 번호를 클릭하면 즉시 자동 로그인됩니다!</p>' +
      '</div>' +
      '<div class="hawon-grid" id="hawon-btn-grid"></div>' +
      '<p class="hawon-status" id="hawon-status"></p>';

    const grid = panel.querySelector("#hawon-btn-grid");
    const statusEl = panel.querySelector("#hawon-status");
    const buttons = {};

    STUDENTS.forEach((student) => {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "hawon-btn";
      btn.textContent = student.num + "번";
      btn.title = "아이디: " + student.id;
      btn.addEventListener("click", () => {
        handleStudentLogin(student, btn, statusEl, true);
      });
      grid.appendChild(btn);
      buttons[student.num] = btn;
    });

    targetContainer.parentNode.insertBefore(panel, targetContainer);

    // 포털에서 번호를 눌러 들어온 경우: 해당 번호의 아이디/비밀번호를 바로 채워 넣기
    const pendingNum = takePendingNum();
    if (pendingNum) {
      const student = STUDENTS[pendingNum - 1];
      const btn = buttons[pendingNum];
      statusEl.textContent = "⏳ [" + pendingNum + "번] 아이디/비밀번호를 입력하는 중...";
      // 입력창이 React에 완전히 연결될 시간을 조금 준 뒤 주입
      setTimeout(() => {
        handleStudentLogin(student, btn, statusEl, AUTO_SUBMIT);
      }, 300);
    }
  }

  // Next.js SPA 로딩 대응: 주기적 확인 및 MutationObserver
  const timer = setInterval(() => {
    if (document.getElementById("username")) {
      injectPanel();
    }
  }, 300);

  setTimeout(() => clearInterval(timer), 10000);

  const observer = new MutationObserver(() => {
    if (document.getElementById("username") && !document.getElementById("hawon-entry-panel")) {
      injectPanel();
    }
  });

  observer.observe(document.body, { childList: true, subtree: true });
})();
