import { Component } from 'react';
import { Provider } from 'react-redux';
import Taro from '@tarojs/taro';
import { store, hydrateStore } from './store';
import { Storage } from './services/storage';
import { get, resetRedirectFlag } from './services/api';
import './styles/variables.scss';
import './styles/global.scss';

type Props = {
  children?: React.ReactNode;
};

/**
 * App 根组件
 * 启动时从 Storage 恢复认证状态，并验证 token 是否有效
 */
class App extends Component<Props> {
  async componentDidMount(): Promise<void> {
    // 1. 从 Storage 恢复状态到 Redux
    // 重置 401 跳转标志，防止上次异常退出后标志卡死
    resetRedirectFlag();
    hydrateStore();

    // 2. 检查是否有 token，有则验证是否有效
    const token = Storage.getToken();
    if (token) {
      try {
        // 验证 token：调用 /users/me
        const user = await get<any>('/users/me', undefined, { noToast: true });
        store.dispatch({ type: 'auth/setUser', payload: user });
        console.log('[App] token 有效，用户:', user?.name);
      } catch (err: any) {
        // token 无效或过期，清除并跳转登录
        console.warn('[App] token 无效，清除并跳转登录:', err.message);
        Storage.clearToken();
        Storage.remove('user_id');
        store.dispatch({ type: 'auth/clear' });
        // 等 tabBar 页面渲染完再跳转，避免白屏
        setTimeout(() => {
          Taro.redirectTo({ url: '/pages/auth/login/index' });
        }, 100);
      }
    } else {
      // 无 token，跳转登录页
      console.log('[App] 无 token，跳转登录页');
      setTimeout(() => {
        Taro.redirectTo({ url: '/pages/auth/login/index' });
      }, 100);
    }
  }

  render(): JSX.Element {
    return (
      <Provider store={store}>
        {this.props.children}
      </Provider>
    );
  }
}

export default App;
