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
    // 1. 重置 401 跳转标志，防止上次异常退出后标志卡死
    resetRedirectFlag();
    // 2. 从 Storage 恢复状态到 Redux
    hydrateStore();

    // 3. 检查是否有 token
    const token = Storage.getToken();
    if (token) {
      try {
        const user = await get<any>('/users/me', undefined, { noToast: true });
        store.dispatch({ type: 'auth/setUser', payload: user });

        // 检查是否有家庭，无则跳引导页
        const res = await get<{ families: any[] }>('/users/me/families', undefined, { noToast: true });
        const families = res?.families ?? [];
        if (!families || families.length === 0) {
          Taro.redirectTo({ url: '/pages/auth/onboarding/index' });
        } else {
          // 有家庭，切换到首页 tab
          const familyId = families[0].family?.id;
          if (familyId) Storage.setCurrentFamilyId(familyId);
          Taro.switchTab({ url: '/pages/home/index' });
        }
      } catch (err: any) {
        // 只有 401（token 无效/过期）才清除 token 并跳转登录
        // 网络错误等临时问题不踢人，保留 token 等下次重试
        const isUnauthorized = err?.isUnauthorized || err?.code === 401 || err?.code === 20001;
        if (isUnauthorized) {
          Storage.clearToken();
          Storage.remove('user_id');
          store.dispatch({ type: 'auth/clear' });
          setTimeout(() => {
            Taro.redirectTo({ url: '/pages/auth/login/index' });
          }, 100);
        }
      }
    } else {
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
