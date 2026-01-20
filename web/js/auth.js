// js/auth.js
// Authentication: login, signup, password reset, session management

import { post, get } from './api.js';
import { createModal, closeModal, showToast, escapeHtml, $ } from './ui.js';

// ============================================
// STATE
// ============================================

let currentUser = null;
const authListeners = new Set();

export function getUser() {
  return currentUser;
}

export function isLoggedIn() {
  return currentUser !== null;
}

export function onAuthChange(callback) {
  authListeners.add(callback);
  return () => authListeners.delete(callback);
}

function notifyAuthChange() {
  for (const callback of authListeners) {
    try {
      callback(currentUser);
    } catch (e) {
      console.error('Auth listener error:', e);
    }
  }
}

// ============================================
// SESSION INITIALIZATION
// ============================================

export async function initAuth() {
  const loggedIn = document.body.dataset.loggedIn === '1';
  
  if (!loggedIn) {
    updateUIForLoggedOut();
    return null;
  }
  
  try {
    const result = await get('profile.php', { useCache: true, cacheTTL: 60000 });
    
    if (result.ok && result.data?.user) {
      currentUser = result.data.user;
      window.tychesUser = currentUser; // Legacy support
      updateUIForLoggedIn();
      notifyAuthChange();
      return result.data;
    }
  } catch (err) {
    console.error('[Auth] Failed to fetch profile:', err);
  }
  
  updateUIForLoggedOut();
  return null;
}

function updateUIForLoggedIn() {
  // Show auth-only elements
  document.querySelectorAll('.auth-only').forEach(el => {
    el.style.display = '';
  });
  
  // Hide logged-out-only elements
  document.querySelectorAll('.logged-out-only').forEach(el => {
    el.style.display = 'none';
  });
  
  // Hide marketing sections
  document.querySelectorAll('.marketing-only').forEach(el => {
    el.style.display = 'none';
  });
  
  // Update user pill
  fillUserPill();
}

function updateUIForLoggedOut() {
  // Hide auth-only elements
  document.querySelectorAll('.auth-only').forEach(el => {
    el.style.display = 'none';
  });
  
  // Show logged-out-only elements
  document.querySelectorAll('.logged-out-only').forEach(el => {
    el.style.display = '';
  });
  
  // Show marketing sections
  document.querySelectorAll('.marketing-only').forEach(el => {
    el.style.display = '';
  });
}

function fillUserPill() {
  const pill = $('#nav-user-pill');
  const initialEl = $('#nav-user-initial');
  const nameEl = $('#nav-user-name');
  
  if (!pill || !currentUser) return;
  
  const initial = (currentUser.name || currentUser.username || '?').trim().charAt(0).toUpperCase();
  if (initialEl) initialEl.textContent = initial;
  if (nameEl) nameEl.textContent = currentUser.username || currentUser.name || '';
  pill.style.display = 'flex';
}

// ============================================
// LOGIN
// ============================================

export function openLoginModal() {
  const content = `
    <form id="login-form" class="auth-form">
      <div class="form-group">
        <label for="login-email">Email</label>
        <input type="email" id="login-email" required autocomplete="email" placeholder="you@example.com">
      </div>
      <div class="form-group">
        <label for="login-password">Password</label>
        <input type="password" id="login-password" required autocomplete="current-password" placeholder="••••••••">
      </div>
      <div id="login-error" class="form-error" style="display:none;"></div>
      <button type="button" class="btn-ghost" id="login-forgot">
        Forgot your password?
      </button>
      <button type="submit" class="btn-primary btn-block">Log in</button>
      <p class="auth-switch">
        Don't have an account? <button type="button" class="btn-link" id="login-to-signup">Sign up</button>
      </p>
    </form>
  `;
  
  createModal('login', 'Welcome back', content);
  
  const form = $('#login-form');
  const emailEl = $('#login-email');
  const passEl = $('#login-password');
  const errorEl = $('#login-error');
  const forgotBtn = $('#login-forgot');
  const toSignupBtn = $('#login-to-signup');
  
  forgotBtn?.addEventListener('click', () => {
    closeModal('login');
    openResetModal();
  });
  
  toSignupBtn?.addEventListener('click', () => {
    closeModal('login');
    openSignupModal();
  });
  
  form?.addEventListener('submit', async (e) => {
    e.preventDefault();
    errorEl.style.display = 'none';
    
    const email = emailEl.value.trim();
    const password = passEl.value;
    
    if (!email || !password) {
      errorEl.textContent = 'Please enter your email and password.';
      errorEl.style.display = 'block';
      return;
    }
    
    const submitBtn = form.querySelector('button[type="submit"]');
    submitBtn.disabled = true;
    submitBtn.textContent = 'Logging in...';
    
    const result = await post('login.php', { email, password });
    
    if (!result.ok) {
      errorEl.textContent = result.error || 'Unable to log in.';
      errorEl.style.display = 'block';
      submitBtn.disabled = false;
      submitBtn.textContent = 'Log in';
      return;
    }
    
    showToast('Welcome back!', 'success');
    closeModal('login');
    
    // Reload to initialize session
    setTimeout(() => window.location.reload(), 500);
  });
}

// ============================================
// SIGNUP
// ============================================

export function openSignupModal() {
  const content = `
    <form id="signup-form" class="auth-form">
      <div class="form-row">
        <div class="form-group">
          <label for="signup-name">Name</label>
          <input type="text" id="signup-name" required placeholder="Your name">
        </div>
        <div class="form-group">
          <label for="signup-username">Username</label>
          <input type="text" id="signup-username" required placeholder="coolpredictor" pattern="[a-zA-Z0-9_]+" title="Letters, numbers, and underscores only">
        </div>
      </div>
      <div class="form-group">
        <label for="signup-email">Email</label>
        <input type="email" id="signup-email" required autocomplete="email" placeholder="you@example.com">
      </div>
      <div class="form-group">
        <label for="signup-phone">Phone <span class="optional">(optional)</span></label>
        <input type="tel" id="signup-phone" placeholder="+1 555 123 4567">
      </div>
      <div class="form-group">
        <label for="signup-password">Password</label>
        <input type="password" id="signup-password" required minlength="8" autocomplete="new-password" placeholder="At least 8 characters">
      </div>
      <div class="form-group">
        <label for="signup-password-confirm">Confirm password</label>
        <input type="password" id="signup-password-confirm" required minlength="8" autocomplete="new-password" placeholder="••••••••">
      </div>
      <div id="signup-error" class="form-error" style="display:none;"></div>
      <div id="signup-success" class="form-success" style="display:none;"></div>
      <button type="submit" class="btn-primary btn-block">Create account</button>
      <p class="auth-switch">
        Already have an account? <button type="button" class="btn-link" id="signup-to-login">Log in</button>
      </p>
    </form>
  `;
  
  createModal('signup', 'Create your account', content);
  
  const form = $('#signup-form');
  const toLoginBtn = $('#signup-to-login');
  
  toLoginBtn?.addEventListener('click', () => {
    closeModal('signup');
    openLoginModal();
  });
  
  form?.addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const errEl = $('#signup-error');
    const okEl = $('#signup-success');
    errEl.style.display = 'none';
    okEl.style.display = 'none';
    
    const name = $('#signup-name').value.trim();
    const username = $('#signup-username').value.trim();
    const email = $('#signup-email').value.trim();
    const phone = $('#signup-phone').value.trim();
    const password = $('#signup-password').value;
    const password_confirmation = $('#signup-password-confirm').value;
    
    if (!name || !username || !email || !password) {
      errEl.textContent = 'Please fill in all required fields.';
      errEl.style.display = 'block';
      return;
    }
    
    if (password !== password_confirmation) {
      errEl.textContent = 'Passwords do not match.';
      errEl.style.display = 'block';
      return;
    }
    
    if (password.length < 8) {
      errEl.textContent = 'Password must be at least 8 characters.';
      errEl.style.display = 'block';
      return;
    }
    
    const submitBtn = form.querySelector('button[type="submit"]');
    submitBtn.disabled = true;
    submitBtn.textContent = 'Creating account...';
    
    const result = await post('users.php', { name, username, email, phone, password, password_confirmation });
    
    if (!result.ok) {
      errEl.textContent = result.error || 'Unable to create account.';
      errEl.style.display = 'block';
      submitBtn.disabled = false;
      submitBtn.textContent = 'Create account';
      return;
    }
    
    okEl.textContent = 'Account created! Check your email to verify before logging in.';
    okEl.style.display = 'block';
    form.reset();
    submitBtn.disabled = false;
    submitBtn.textContent = 'Create account';
  });
}

// ============================================
// PASSWORD RESET
// ============================================

export function openResetModal() {
  const content = `
    <form id="reset-form" class="auth-form">
      <p class="form-description">Enter your email and we'll send you a link to reset your password.</p>
      <div class="form-group">
        <label for="reset-email">Email</label>
        <input type="email" id="reset-email" required autocomplete="email" placeholder="you@example.com">
      </div>
      <div id="reset-error" class="form-error" style="display:none;"></div>
      <div id="reset-success" class="form-success" style="display:none;"></div>
      <button type="submit" class="btn-primary btn-block">Send reset link</button>
      <p class="auth-switch">
        Remember your password? <button type="button" class="btn-link" id="reset-to-login">Log in</button>
      </p>
    </form>
  `;
  
  createModal('reset', 'Reset your password', content);
  
  const form = $('#reset-form');
  const toLoginBtn = $('#reset-to-login');
  
  toLoginBtn?.addEventListener('click', () => {
    closeModal('reset');
    openLoginModal();
  });
  
  form?.addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const errEl = $('#reset-error');
    const okEl = $('#reset-success');
    errEl.style.display = 'none';
    okEl.style.display = 'none';
    
    const email = $('#reset-email').value.trim();
    
    if (!email) {
      errEl.textContent = 'Please enter your email.';
      errEl.style.display = 'block';
      return;
    }
    
    const submitBtn = form.querySelector('button[type="submit"]');
    submitBtn.disabled = true;
    submitBtn.textContent = 'Sending...';
    
    const result = await post('password-reset-request.php', { email });
    
    submitBtn.disabled = false;
    submitBtn.textContent = 'Send reset link';
    
    if (!result.ok) {
      errEl.textContent = result.error || 'Could not send reset email.';
      errEl.style.display = 'block';
      return;
    }
    
    okEl.textContent = "If that email exists, we've sent you a reset link.";
    okEl.style.display = 'block';
  });
}

// ============================================
// LOGOUT
// ============================================

export async function logout() {
  const result = await post('logout.php');
  
  if (result.ok) {
    currentUser = null;
    window.tychesUser = null;
    showToast('Logged out successfully', 'info');
    setTimeout(() => {
      window.location.href = 'index.php';
    }, 500);
  } else {
    showToast('Failed to log out', 'error');
  }
}

// ============================================
// NAVIGATION SETUP
// ============================================

export function setupAuthNav() {
  // Login button
  $('#nav-login')?.addEventListener('click', openLoginModal);
  
  // Get started button
  $('#nav-get-started')?.addEventListener('click', openSignupModal);
  
  // Hero CTA
  $('#hero-start-market')?.addEventListener('click', openSignupModal);
  
  // User pill dropdown
  const userPill = $('#nav-user-pill');
  const dropdown = $('#nav-user-dropdown');
  
  if (userPill && dropdown) {
    userPill.addEventListener('click', (e) => {
      e.stopPropagation();
      const isOpen = dropdown.style.display === 'flex';
      dropdown.style.display = isOpen ? 'none' : 'flex';
    });
    
    document.addEventListener('click', () => {
      dropdown.style.display = 'none';
    });
  }
  
  // Dropdown buttons
  $('#nav-open-profile')?.addEventListener('click', () => {
    window.location.href = 'profile.php';
  });
  
  $('#nav-open-markets')?.addEventListener('click', () => {
    window.location.href = 'index.php';
  });
  
  $('#nav-logout')?.addEventListener('click', logout);
  
  // Profile nav button
  $('#nav-profile')?.addEventListener('click', () => {
    window.location.href = 'profile.php';
  });
}

export default {
  initAuth,
  getUser,
  isLoggedIn,
  onAuthChange,
  openLoginModal,
  openSignupModal,
  openResetModal,
  logout,
  setupAuthNav,
};

