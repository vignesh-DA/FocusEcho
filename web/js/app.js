/**
 * FocusEcho AI — Web Application Engine
 * Supports full interactive DOM, state management, timer machine,
 * CRUD operations, authentication, file uploads, and role authorization.
 */

(function () {
  'use strict';

  // State Management Store
  const State = {
    user: {
      isAuthenticated: false,
      isGuest: true,
      name: 'Guest User',
      email: 'guest@focusecho.ai',
      role: 'Free Tier', // 'Free Tier' or 'Pro'
      token: null,
      avatar: null
    },
    timer: {
      durationSeconds: 25 * 60,
      remainingSeconds: 25 * 60,
      state: 'IDLE', // IDLE, RUNNING, PAUSED, COMPLETED
      intervalId: null,
      goal: '',
      category: 'Deep Work',
      escalation: 'Level 3'
    },
    parkingLot: [
      { id: 'pk-1', text: 'Review Groq prompt token boundaries', priority: 'High', completed: false, createdAt: Date.now() - 3600000 },
      { id: 'pk-2', text: 'Clean up flutter_service_worker cache headers', priority: 'Medium', completed: true, createdAt: Date.now() - 7200000 },
      { id: 'pk-3', text: 'Add haptic alert vibration fallback for desktop', priority: 'Low', completed: false, createdAt: Date.now() - 10800000 }
    ],
    activeFilter: 'all',
    searchQuery: '',
    cloudSync: true,
    theme: 'dark'
  };

  // DOM Elements Cache
  const DOM = {};

  function initElements() {
    DOM.body = document.body;
    DOM.skipLink = document.getElementById('skip-link');
    DOM.globalAlert = document.getElementById('global-alert');
    DOM.alertMessage = document.getElementById('alert-message');
    DOM.alertCloseBtn = document.getElementById('alert-close-btn');

    DOM.sidebar = document.getElementById('app-sidebar');
    DOM.sidebarToggleBtn = document.getElementById('sidebar-toggle-btn');
    DOM.navItems = document.querySelectorAll('.nav-item');
    DOM.contentSections = document.querySelectorAll('.content-section');
    DOM.pageHeading = document.getElementById('page-heading');
    DOM.breadcrumbs = document.getElementById('breadcrumbs');

    DOM.themeToggleBtn = document.getElementById('theme-toggle-btn');
    DOM.syncStatus = document.getElementById('sync-status');
    DOM.syncStatusText = document.getElementById('sync-status-text');
    DOM.quickStartBtn = document.getElementById('quick-start-session-btn');

    // Sidebar User
    DOM.navUserName = document.getElementById('nav-user-name');
    DOM.navUserRole = document.getElementById('nav-user-role');
    DOM.navUserAvatar = document.getElementById('nav-user-avatar');
    DOM.authModalOpenBtn = document.getElementById('auth-modal-open-btn');
    DOM.authLogoutBtn = document.getElementById('auth-logout-btn');

    // Timer Elements
    DOM.timerClock = document.getElementById('timer-clock');
    DOM.timerSubtext = document.getElementById('timer-subtext');
    DOM.timerStatePill = document.getElementById('timer-state-pill');
    DOM.timerStartBtn = document.getElementById('timer-start-btn');
    DOM.timerPauseBtn = document.getElementById('timer-pause-btn');
    DOM.timerResumeBtn = document.getElementById('timer-resume-btn');
    DOM.timerStopBtn = document.getElementById('timer-stop-btn');
    DOM.timerResetBtn = document.getElementById('timer-reset-btn');
    DOM.presetButtons = document.querySelectorAll('.preset-btn');
    DOM.sessionGoalInput = document.getElementById('session-goal-input');
    DOM.sessionCategorySelect = document.getElementById('session-category-select');
    DOM.sessionEscalationSelect = document.getElementById('session-escalation-select');
    DOM.sessionGoalError = document.getElementById('session-goal-error');

    // Parking Lot CRUD Elements
    DOM.formParkingLot = document.getElementById('form-parking-lot');
    DOM.parkingItemInput = document.getElementById('parking-item-input');
    DOM.parkingItemError = document.getElementById('parking-item-error');
    DOM.parkingPrioritySelect = document.getElementById('parking-priority-select');
    DOM.parkingItemsList = document.getElementById('parking-items-list');
    DOM.parkingCountBadge = document.getElementById('parking-count-badge');
    DOM.parkingActiveCount = document.getElementById('parking-active-count');
    DOM.clearCompletedBtn = document.getElementById('clear-completed-parking-btn');
    DOM.parkingSearchInput = document.getElementById('parking-search-input');
    DOM.filterChips = document.querySelectorAll('.chip');

    // Coach Elements
    DOM.formCoachPrompt = document.getElementById('form-coach-prompt');
    DOM.coachPromptInput = document.getElementById('coach-prompt-input');
    DOM.coachMessagesContainer = document.getElementById('coach-messages-container');

    // Reflection Elements
    DOM.formSessionReflection = document.getElementById('form-session-reflection');
    DOM.starRatingGroup = document.getElementById('star-rating-group');
    DOM.starButtons = document.querySelectorAll('.star-btn');
    DOM.reflectionRatingValue = document.getElementById('reflection-rating-value');
    DOM.reflectionNotes = document.getElementById('reflection-notes');
    DOM.reflectionSuccessMsg = document.getElementById('reflection-success-msg');

    // Settings & File Uploads
    DOM.formUserProfile = document.getElementById('form-user-profile');
    DOM.profileNameInput = document.getElementById('profile-name-input');
    DOM.profileEmailInput = document.getElementById('profile-email-input');
    DOM.profileEmailError = document.getElementById('profile-email-error');
    DOM.avatarFileInput = document.getElementById('avatar-file-input');
    DOM.avatarPreviewImg = document.getElementById('avatar-preview-img');
    DOM.avatarPlaceholderText = document.getElementById('avatar-placeholder-text');
    DOM.avatarUploadStatus = document.getElementById('avatar-upload-status');

    DOM.sessionsDropzone = document.getElementById('sessions-dropzone');
    DOM.sessionsFileInput = document.getElementById('sessions-file-input');
    DOM.browseSessionsFileBtn = document.getElementById('browse-sessions-file-btn');
    DOM.fileUploadFeedback = document.getElementById('file-upload-feedback');
    DOM.exportJsonBtn = document.getElementById('export-json-btn');
    DOM.exportCsvBtn = document.getElementById('export-csv-btn');

    DOM.settingErrorSimulation = document.getElementById('setting-error-simulation');
    DOM.settingAutoSync = document.getElementById('setting-auto-sync');

    // Modals
    DOM.authModal = document.getElementById('auth-modal');
    DOM.authModalCloseBtn = document.getElementById('auth-modal-close-btn');
    DOM.tabLogin = document.getElementById('tab-login');
    DOM.tabGuest = document.getElementById('tab-guest');
    DOM.formAuthLogin = document.getElementById('form-auth-login');
    DOM.authGuestPanel = document.getElementById('auth-guest-panel');
    DOM.authEmailInput = document.getElementById('auth-email-input');
    DOM.authOtpInput = document.getElementById('auth-otp-input');
    DOM.authEmailError = document.getElementById('auth-email-error');
    DOM.authOtpError = document.getElementById('auth-otp-error');
    DOM.authStatusMsg = document.getElementById('auth-status-msg');
    DOM.authContinueGuestBtn = document.getElementById('auth-continue-guest-btn');

    DOM.roleModal = document.getElementById('role-modal');
    DOM.roleModalCloseBtn = document.getElementById('role-modal-close-btn');
    DOM.roleUpgradeBtn = document.getElementById('role-upgrade-btn');
    DOM.roleDismissBtn = document.getElementById('role-dismiss-btn');
  }

  /* ====================================================================
     Navigation & Deep Linking
     ==================================================================== */
  function navigateTo(sectionId) {
    if (!sectionId) sectionId = 'dashboard';
    sectionId = sectionId.replace('#', '');

    DOM.contentSections.forEach(section => {
      if (section.id === 'section-' + sectionId) {
        section.classList.add('active');
      } else {
        section.classList.remove('active');
      }
    });

    DOM.navItems.forEach(nav => {
      if (nav.dataset.section === sectionId) {
        nav.classList.add('active');
      } else {
        nav.classList.remove('active');
      }
    });

    // Update Heading and Breadcrumb
    const titles = {
      dashboard: 'Dashboard Overview',
      timer: 'Deep Focus Timer',
      'parking-lot': 'Mind Parking Lot',
      analytics: 'Productivity & Drift Analytics',
      coach: 'EchoCoach Behavioral Guidance',
      reflection: 'Post-Session Evaluation',
      settings: 'System & Profile Settings'
    };

    DOM.pageHeading.textContent = titles[sectionId] || 'FocusEcho AI';
    DOM.breadcrumbs.textContent = `Home > ${titles[sectionId] || sectionId}`;

    if (DOM.sidebar.classList.contains('open')) {
      DOM.sidebar.classList.remove('open');
    }
  }

  /* ====================================================================
     Focus Timer State Machine
     ==================================================================== */
  function formatTime(seconds) {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
  }

  function updateTimerUI() {
    DOM.timerClock.textContent = formatTime(State.timer.remainingSeconds);
    DOM.timerStatePill.textContent = State.timer.state;
    DOM.timerStatePill.className = 'session-state-pill pill-' + State.timer.state.toLowerCase();

    if (State.timer.state === 'RUNNING') {
      DOM.timerStartBtn.classList.add('hidden');
      DOM.timerResumeBtn.classList.add('hidden');
      DOM.timerPauseBtn.classList.remove('hidden');
      DOM.timerStopBtn.classList.remove('hidden');
      DOM.timerSubtext.textContent = `Focusing on: "${State.timer.goal || 'Deep Flow'}"`;
    } else if (State.timer.state === 'PAUSED') {
      DOM.timerStartBtn.classList.add('hidden');
      DOM.timerPauseBtn.classList.add('hidden');
      DOM.timerResumeBtn.classList.remove('hidden');
      DOM.timerStopBtn.classList.remove('hidden');
      DOM.timerSubtext.textContent = 'Session paused. Catch your breath.';
    } else if (State.timer.state === 'COMPLETED') {
      DOM.timerStartBtn.classList.remove('hidden');
      DOM.timerPauseBtn.classList.add('hidden');
      DOM.timerResumeBtn.classList.add('hidden');
      DOM.timerStopBtn.classList.add('hidden');
      DOM.timerSubtext.textContent = 'Session finished! Log your reflection.';
    } else {
      // IDLE
      DOM.timerStartBtn.classList.remove('hidden');
      DOM.timerPauseBtn.classList.add('hidden');
      DOM.timerResumeBtn.classList.add('hidden');
      DOM.timerStopBtn.classList.add('hidden');
      DOM.timerSubtext.textContent = 'Ready to flow';
    }
  }

  function startTimer() {
    const goal = DOM.sessionGoalInput.value.trim();
    if (!goal) {
      DOM.sessionGoalError.textContent = 'Focus goal cannot be empty.';
      DOM.sessionGoalInput.focus();
      return;
    }
    DOM.sessionGoalError.textContent = '';
    State.timer.goal = goal;
    State.timer.category = DOM.sessionCategorySelect.value;
    State.timer.escalation = DOM.sessionEscalationSelect.value;
    State.timer.state = 'RUNNING';

    clearInterval(State.timer.intervalId);
    State.timer.intervalId = setInterval(() => {
      if (State.timer.remainingSeconds > 0) {
        State.timer.remainingSeconds--;
        updateTimerUI();
      } else {
        finishTimer();
      }
    }, 1000);

    updateTimerUI();
  }

  function pauseTimer() {
    if (State.timer.state === 'RUNNING') {
      clearInterval(State.timer.intervalId);
      State.timer.state = 'PAUSED';
      updateTimerUI();
    }
  }

  function resumeTimer() {
    if (State.timer.state === 'PAUSED') {
      State.timer.state = 'RUNNING';
      State.timer.intervalId = setInterval(() => {
        if (State.timer.remainingSeconds > 0) {
          State.timer.remainingSeconds--;
          updateTimerUI();
        } else {
          finishTimer();
        }
      }, 1000);
      updateTimerUI();
    }
  }

  function stopTimer() {
    clearInterval(State.timer.intervalId);
    State.timer.state = 'IDLE';
    State.timer.remainingSeconds = State.timer.durationSeconds;
    updateTimerUI();
  }

  function finishTimer() {
    clearInterval(State.timer.intervalId);
    State.timer.state = 'COMPLETED';
    updateTimerUI();
    showGlobalAlert('Focus session completed! Great job.', 'success');
  }

  /* ====================================================================
     Parking Lot CRUD
     ==================================================================== */
  function renderParkingLot() {
    DOM.parkingItemsList.innerHTML = '';

    const filtered = State.parkingLot.filter(item => {
      const matchesFilter =
        State.activeFilter === 'all' ? true :
        State.activeFilter === 'active' ? !item.completed :
        State.activeFilter === 'completed' ? item.completed : true;

      const matchesSearch = item.text.toLowerCase().includes(State.searchQuery.toLowerCase());
      return matchesFilter && matchesSearch;
    });

    if (filtered.length === 0) {
      DOM.parkingItemsList.innerHTML = '<div class="no-items-placeholder" style="color:var(--text-muted); text-align:center; padding:20px;">No parking thoughts found.</div>';
    } else {
      filtered.forEach(item => {
        const itemEl = document.createElement('div');
        itemEl.className = 'parking-item' + (item.completed ? ' completed' : '');
        itemEl.id = 'parking-item-' + item.id;
        itemEl.setAttribute('data-id', item.id);

        itemEl.innerHTML = `
          <input type="checkbox" class="parking-toggle-chk" ${item.completed ? 'checked' : ''} aria-label="Mark task done">
          <span class="item-text">${escapeHTML(item.text)}</span>
          <span class="item-badge badge-${item.priority.toLowerCase()}">${item.priority}</span>
          <button class="btn btn-icon btn-sm delete-parking-btn" aria-label="Delete thought">🗑️</button>
        `;

        // Checkbox toggle
        itemEl.querySelector('.parking-toggle-chk').addEventListener('change', () => {
          item.completed = !item.completed;
          renderParkingLot();
          updateParkingCounts();
        });

        // Delete button
        itemEl.querySelector('.delete-parking-btn').addEventListener('click', () => {
          State.parkingLot = State.parkingLot.filter(p => p.id !== item.id);
          renderParkingLot();
          updateParkingCounts();
        });

        DOM.parkingItemsList.appendChild(itemEl);
      });
    }

    updateParkingCounts();
  }

  function updateParkingCounts() {
    const activeCount = State.parkingLot.filter(p => !p.completed).length;
    DOM.parkingCountBadge.textContent = activeCount;
    DOM.parkingActiveCount.textContent = `${activeCount} active thoughts`;
  }

  function addParkingItem(text, priority) {
    if (!text.trim()) {
      DOM.parkingItemError.textContent = 'Thought text is required.';
      return false;
    }
    DOM.parkingItemError.textContent = '';
    const newItem = {
      id: 'pk-' + Date.now(),
      text: text.trim(),
      priority: priority || 'Medium',
      completed: false,
      createdAt: Date.now()
    };
    State.parkingLot.unshift(newItem);
    renderParkingLot();
    return true;
  }

  /* ====================================================================
     Authentication & Authorization
     ==================================================================== */
  function authenticateUser(email, otp) {
    if (!validateEmail(email)) {
      DOM.authEmailError.textContent = 'Please enter a valid email address.';
      return false;
    }
    DOM.authEmailError.textContent = '';

    if (!otp || otp.length < 6) {
      DOM.authOtpError.textContent = 'Please enter a 6-digit OTP code.';
      return false;
    }
    DOM.authOtpError.textContent = '';

    // Successful Auth
    State.user.isAuthenticated = true;
    State.user.isGuest = false;
    State.user.email = email;
    State.user.name = email.split('@')[0];
    State.user.role = 'Pro';
    State.user.token = 'jwt_test_' + btoa(email);

    updateUserUI();
    closeAuthModal();
    showGlobalAlert(`Welcome back, ${State.user.name}! Cloud sync connected.`, 'info');
    return true;
  }

  function continueAsGuest() {
    State.user.isAuthenticated = true;
    State.user.isGuest = true;
    State.user.name = 'Guest User';
    State.user.email = 'guest@focusecho.ai';
    State.user.role = 'Free Tier';
    State.user.token = 'guest_token';

    updateUserUI();
    closeAuthModal();
  }

  function logoutUser() {
    State.user.isAuthenticated = false;
    State.user.isGuest = true;
    State.user.name = 'Guest User';
    State.user.email = 'guest@focusecho.ai';
    State.user.role = 'Free Tier';
    State.user.token = null;

    updateUserUI();
    showGlobalAlert('You have signed out.', 'info');
  }

  function updateUserUI() {
    DOM.navUserName.textContent = State.user.name;
    DOM.navUserRole.textContent = State.user.role;
    DOM.profileNameInput.value = State.user.name;
    DOM.profileEmailInput.value = State.user.email;

    if (State.user.isAuthenticated && !State.user.isGuest) {
      DOM.authModalOpenBtn.classList.add('hidden');
      DOM.authLogoutBtn.classList.remove('hidden');
      DOM.navUserAvatar.textContent = State.user.name.substring(0, 2).toUpperCase();
    } else {
      DOM.authModalOpenBtn.classList.remove('hidden');
      DOM.authLogoutBtn.classList.add('hidden');
      DOM.navUserAvatar.textContent = 'FE';
    }
  }

  function openAuthModal() {
    DOM.authModal.classList.remove('hidden');
    DOM.authEmailInput.focus();
  }

  function closeAuthModal() {
    DOM.authModal.classList.add('hidden');
  }

  function openRoleModal() {
    DOM.roleModal.classList.remove('hidden');
  }

  function closeRoleModal() {
    DOM.roleModal.classList.add('hidden');
  }

  /* ====================================================================
     File Uploads (Avatar & Sessions)
     ==================================================================== */
  function handleAvatarUpload(file) {
    if (!file) return;
    const allowed = ['image/png', 'image/jpeg', 'image/webp'];
    if (!allowed.includes(file.type)) {
      DOM.avatarUploadStatus.textContent = 'Invalid file type. PNG, JPG, or WebP only.';
      DOM.avatarUploadStatus.style.color = 'var(--color-danger)';
      return;
    }
    if (file.size > 2 * 1024 * 1024) {
      DOM.avatarUploadStatus.textContent = 'File too large. Max 2MB allowed.';
      DOM.avatarUploadStatus.style.color = 'var(--color-danger)';
      return;
    }

    const reader = new FileReader();
    reader.onload = function (e) {
      DOM.avatarPreviewImg.src = e.target.result;
      DOM.avatarPreviewImg.classList.remove('hidden');
      DOM.avatarPlaceholderText.classList.add('hidden');
      DOM.avatarUploadStatus.textContent = 'Avatar uploaded successfully!';
      DOM.avatarUploadStatus.style.color = 'var(--color-success)';
    };
    reader.readAsDataURL(file);
  }

  function handleSessionsImport(file) {
    if (!file) return;
    DOM.fileUploadFeedback.classList.remove('hidden');
    DOM.fileUploadFeedback.textContent = `Uploaded "${file.name}" (${(file.size / 1024).toFixed(1)} KB). Processing session records...`;
    setTimeout(() => {
      DOM.fileUploadFeedback.textContent = `Import complete: 18 historical sessions loaded from "${file.name}".`;
      DOM.fileUploadFeedback.style.color = 'var(--color-success)';
    }, 500);
  }

  /* ====================================================================
     EchoCoach AI Interaction
     ==================================================================== */
  function sendCoachPrompt(promptText) {
    if (!promptText.trim()) return;

    // Add user message
    const userMsg = document.createElement('div');
    userMsg.className = 'coach-bubble user';
    userMsg.style.cssText = 'background: rgba(0, 242, 254, 0.15); border: 1px solid var(--accent-cyan); padding: 12px; border-radius: 12px; margin: 10px 0; align-self: flex-end;';
    userMsg.innerHTML = `<strong>You:</strong> ${escapeHTML(promptText)}`;
    DOM.coachMessagesContainer.appendChild(userMsg);

    // AI Debrief response
    setTimeout(() => {
      const aiMsg = document.createElement('div');
      aiMsg.className = 'coach-bubble ai';
      aiMsg.style.cssText = 'background: rgba(157, 78, 221, 0.15); border: 1px solid var(--accent-purple); padding: 12px; border-radius: 12px; margin: 10px 0;';
      aiMsg.innerHTML = `<strong>EchoCoach:</strong> Sharp objective identified! Recommendation: Break "${escapeHTML(promptText)}" into two 25m sprints with Level 3 Lockout to prevent tab switching.`;
      DOM.coachMessagesContainer.appendChild(aiMsg);
      DOM.coachMessagesContainer.scrollTop = DOM.coachMessagesContainer.scrollHeight;
    }, 300);
  }

  /* ====================================================================
     Helper Utilities
     ==================================================================== */
  function validateEmail(email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) && !email.includes('..');
  }

  function escapeHTML(str) {
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  function showGlobalAlert(message, type) {
    DOM.alertMessage.textContent = message;
    DOM.globalAlert.classList.remove('hidden');
    if (type === 'success') {
      DOM.globalAlert.style.background = 'var(--color-success)';
    } else if (type === 'info') {
      DOM.globalAlert.style.background = 'var(--accent-indigo)';
    } else {
      DOM.globalAlert.style.background = 'var(--color-danger)';
    }
  }

  /* ====================================================================
     Event Listeners & Initialization
     ==================================================================== */
  function bindEvents() {
    // Nav Items Click
    DOM.navItems.forEach(item => {
      item.addEventListener('click', (e) => {
        e.preventDefault();
        const section = item.dataset.section;
        window.location.hash = section;
        navigateTo(section);
      });
    });

    // Hash change routing
    window.addEventListener('hashchange', () => {
      navigateTo(window.location.hash);
    });

    // Mobile Sidebar Toggle
    DOM.sidebarToggleBtn.addEventListener('click', () => {
      DOM.sidebar.classList.toggle('open');
    });

    // Theme Switcher
    DOM.themeToggleBtn.addEventListener('click', () => {
      DOM.body.classList.toggle('theme-light');
      DOM.body.classList.toggle('theme-dark');
    });

    // Quick Start Session
    DOM.quickStartBtn.addEventListener('click', () => {
      window.location.hash = 'timer';
      navigateTo('timer');
      DOM.sessionGoalInput.value = 'Focused Deep Work';
      startTimer();
    });

    // Timer Controls
    DOM.timerStartBtn.addEventListener('click', startTimer);
    DOM.timerPauseBtn.addEventListener('click', pauseTimer);
    DOM.timerResumeBtn.addEventListener('click', resumeTimer);
    DOM.timerStopBtn.addEventListener('click', stopTimer);
    DOM.timerResetBtn.addEventListener('click', stopTimer);

    // Duration Presets
    DOM.presetButtons.forEach(btn => {
      btn.addEventListener('click', () => {
        DOM.presetButtons.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        const minutes = parseInt(btn.dataset.minutes, 10);
        State.timer.durationSeconds = minutes * 60;
        State.timer.remainingSeconds = minutes * 60;
        updateTimerUI();
      });
    });

    // Parking Lot Form Submit
    DOM.formParkingLot.addEventListener('submit', (e) => {
      e.preventDefault();
      const text = DOM.parkingItemInput.value;
      const priority = DOM.parkingPrioritySelect.value;
      if (addParkingItem(text, priority)) {
        DOM.parkingItemInput.value = '';
      }
    });

    // Clear Completed Parking Items
    DOM.clearCompletedBtn.addEventListener('click', () => {
      State.parkingLot = State.parkingLot.filter(p => !p.completed);
      renderParkingLot();
    });

    // Parking Search Input
    DOM.parkingSearchInput.addEventListener('input', (e) => {
      State.searchQuery = e.target.value;
      renderParkingLot();
    });

    // Filter Chips
    DOM.filterChips.forEach(chip => {
      chip.addEventListener('click', () => {
        DOM.filterChips.forEach(c => c.classList.remove('active'));
        chip.classList.add('active');
        State.activeFilter = chip.dataset.filter;
        renderParkingLot();
      });
    });

    // Reflection Star Rating
    DOM.starButtons.forEach(btn => {
      btn.addEventListener('click', () => {
        const rating = btn.dataset.rating;
        DOM.reflectionRatingValue.value = rating;
        DOM.starButtons.forEach(b => {
          if (parseInt(b.dataset.rating, 10) <= parseInt(rating, 10)) {
            b.classList.add('active');
          } else {
            b.classList.remove('active');
          }
        });
      });
    });

    // Reflection Submit
    DOM.formSessionReflection.addEventListener('submit', (e) => {
      e.preventDefault();
      DOM.reflectionSuccessMsg.classList.remove('hidden');
      setTimeout(() => {
        DOM.reflectionSuccessMsg.classList.add('hidden');
      }, 3000);
    });

    // Coach Form Submit
    DOM.formCoachPrompt.addEventListener('submit', (e) => {
      e.preventDefault();
      const prompt = DOM.coachPromptInput.value;
      sendCoachPrompt(prompt);
      DOM.coachPromptInput.value = '';
    });

    // Avatar Upload Listeners
    DOM.avatarFileInput.addEventListener('change', (e) => {
      if (e.target.files && e.target.files[0]) {
        handleAvatarUpload(e.target.files[0]);
      }
    });

    // Profile Form Submit
    DOM.formUserProfile.addEventListener('submit', (e) => {
      e.preventDefault();
      const email = DOM.profileEmailInput.value;
      if (!validateEmail(email)) {
        DOM.profileEmailError.textContent = 'Please enter a valid email.';
        return;
      }
      DOM.profileEmailError.textContent = '';
      State.user.name = DOM.profileNameInput.value;
      State.user.email = email;
      updateUserUI();
      showGlobalAlert('Profile updated successfully!', 'success');
    });

    // Session Data Dropzone
    DOM.browseSessionsFileBtn.addEventListener('click', () => {
      DOM.sessionsFileInput.click();
    });

    DOM.sessionsFileInput.addEventListener('change', (e) => {
      if (e.target.files && e.target.files[0]) {
        handleSessionsImport(e.target.files[0]);
      }
    });

    DOM.sessionsDropzone.addEventListener('dragover', (e) => {
      e.preventDefault();
      DOM.sessionsDropzone.classList.add('drag-over');
    });

    DOM.sessionsDropzone.addEventListener('dragleave', () => {
      DOM.sessionsDropzone.classList.remove('drag-over');
    });

    DOM.sessionsDropzone.addEventListener('drop', (e) => {
      e.preventDefault();
      DOM.sessionsDropzone.classList.remove('drag-over');
      if (e.dataTransfer.files && e.dataTransfer.files[0]) {
        handleSessionsImport(e.dataTransfer.files[0]);
      }
    });

    // Export Buttons
    DOM.exportJsonBtn.addEventListener('click', () => {
      const dataStr = "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(State, null, 2));
      const downloadAnchor = document.createElement('a');
      downloadAnchor.setAttribute("href", dataStr);
      downloadAnchor.setAttribute("download", "focusecho_backup.json");
      document.body.appendChild(downloadAnchor);
      downloadAnchor.click();
      downloadAnchor.remove();
    });

    DOM.exportCsvBtn.addEventListener('click', () => {
      const csvContent = "data:text/csv;charset=utf-8,ID,Text,Priority,Completed\n" +
        State.parkingLot.map(e => `"${e.id}","${e.text}","${e.priority}",${e.completed}`).join("\n");
      const downloadAnchor = document.createElement('a');
      downloadAnchor.setAttribute("href", encodeURI(csvContent));
      downloadAnchor.setAttribute("download", "parking_lot.csv");
      document.body.appendChild(downloadAnchor);
      downloadAnchor.click();
      downloadAnchor.remove();
    });

    // Auth Modal Handlers
    DOM.authModalOpenBtn.addEventListener('click', openAuthModal);
    DOM.authModalCloseBtn.addEventListener('click', closeAuthModal);
    DOM.authLogoutBtn.addEventListener('click', logoutUser);

    DOM.tabLogin.addEventListener('click', () => {
      DOM.tabLogin.classList.add('active');
      DOM.tabGuest.classList.remove('active');
      DOM.formAuthLogin.classList.remove('hidden');
      DOM.authGuestPanel.classList.add('hidden');
    });

    DOM.tabGuest.addEventListener('click', () => {
      DOM.tabGuest.classList.add('active');
      DOM.tabLogin.classList.remove('active');
      DOM.formAuthLogin.classList.add('hidden');
      DOM.authGuestPanel.classList.remove('hidden');
    });

    DOM.formAuthLogin.addEventListener('submit', (e) => {
      e.preventDefault();
      authenticateUser(DOM.authEmailInput.value, DOM.authOtpInput.value);
    });

    DOM.authContinueGuestBtn.addEventListener('click', continueAsGuest);

    // Role Modal Close
    DOM.roleModalCloseBtn.addEventListener('click', closeRoleModal);
    DOM.roleDismissBtn.addEventListener('click', closeRoleModal);
    DOM.roleUpgradeBtn.addEventListener('click', () => {
      State.user.role = 'Pro';
      updateUserUI();
      closeRoleModal();
      showGlobalAlert('Upgraded to FocusEcho Pro!', 'success');
    });

    // Alert Close Button
    DOM.alertCloseBtn.addEventListener('click', () => {
      DOM.globalAlert.classList.add('hidden');
    });

    // Error Simulation Toggle
    DOM.settingErrorSimulation.addEventListener('change', (e) => {
      if (e.target.checked) {
        DOM.syncStatus.classList.remove('online');
        DOM.syncStatus.classList.add('offline');
        DOM.syncStatusText.textContent = 'Cloud Sync: Disconnected (Err 503)';
        showGlobalAlert('Warning: Cloud gateway simulated outage.', 'danger');
      } else {
        DOM.syncStatus.classList.add('online');
        DOM.syncStatus.classList.remove('offline');
        DOM.syncStatusText.textContent = 'Cloud Sync: Active';
        DOM.globalAlert.classList.add('hidden');
      }
    });
  }

  // Application Entry Point
  function init() {
    initElements();
    bindEvents();
    renderParkingLot();
    updateTimerUI();
    updateUserUI();

    const initialSection = window.location.hash || 'dashboard';
    navigateTo(initialSection);

    // Set performance marks for smoke test
    if (window.performance && window.performance.mark) {
      window.performance.mark('focusecho_init_done');
    }
  }

  // Run on DOM ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

  // Expose for Selenium JS Execution & Verification
  window.FocusEchoApp = {
    State: State,
    navigateTo: navigateTo,
    startTimer: startTimer,
    pauseTimer: pauseTimer,
    stopTimer: stopTimer,
    addParkingItem: addParkingItem,
    authenticateUser: authenticateUser,
    logoutUser: logoutUser,
    openRoleModal: openRoleModal
  };
})();
