/**
 * Redux Store
 * 使用 react-redux
 * 管理认证状态和全局状态
 */

import { createStore, applyMiddleware, combineReducers } from 'redux';
import { thunk } from 'redux-thunk';

// ─── Auth Slice ───────────────────────────────────────────────
interface AuthState {
  token: string | null;
  user: any | null;
  isLoading: boolean;
}

const initialAuthState: AuthState = {
  token: null,
  user: null,
  isLoading: false,
};

function authReducer(state = initialAuthState, action: any): AuthState {
  switch (action.type) {
    case 'auth/setToken':
      return { ...state, token: action.payload };
    case 'auth/setUser':
      return { ...state, user: action.payload };
    case 'auth/setLoading':
      return { ...state, isLoading: action.payload };
    case 'auth/clear':
      return { ...state, token: null, user: null };
    default:
      return state;
  }
}

// ─── Family Slice ─────────────────────────────────────────────
interface FamilyState {
  currentFamilyId: string | null;
  currentFamily: any | null;
}

const initialFamilyState: FamilyState = {
  currentFamilyId: null,
  currentFamily: null,
};

function familyReducer(state = initialFamilyState, action: any): FamilyState {
  switch (action.type) {
    case 'family/setCurrentFamily':
      return { ...state, currentFamily: action.payload };
    case 'family/setCurrentFamilyId':
      return { ...state, currentFamilyId: action.payload };
    default:
      return state;
  }
}

// ─── Root Reducer ──────────────────────────────────────────────
const rootReducer = combineReducers({
  auth: authReducer,
  family: familyReducer,
});

export const store = createStore(rootReducer, applyMiddleware(thunk));

// ─── Selectors ───────────────────────────────────────────────
export const selectIsLoggedIn = (state: { auth: AuthState }) =>
  !!state.auth.token;

export const selectCurrentUser = (state: { auth: AuthState }) =>
  state.auth.user;

export const selectCurrentFamilyId = (state: { family: FamilyState }) =>
  state.family.currentFamilyId;

/**
 * 从 Storage 恢复状态（在 App mount 时调用）
 * 避免模块初始化时调用 Taro API
 */
export function hydrateStore(): void {
  try {
    const token = Taro.getStorageSync('yijiahu_access_token');
    if (token) {
      store.dispatch({ type: 'auth/setToken', payload: token });
    }
    const familyId = Taro.getStorageSync('yijiahu_current_family_id');
    if (familyId) {
      store.dispatch({ type: 'family/setCurrentFamilyId', payload: familyId });
    }
  } catch (e) {
    // ignore storage errors
  }
}
