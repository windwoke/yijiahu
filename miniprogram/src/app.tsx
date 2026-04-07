import { Component } from 'react';
import { Provider } from 'react-redux';
import { store, hydrateStore } from './store';
import './styles/variables.scss';
import './styles/global.scss';

type Props = {
  children?: React.ReactNode;
};

/**
 * App 根组件
 */
class App extends Component<Props> {
  componentDidMount(): void {
    // 组件挂载后从 Storage 恢复状态
    hydrateStore();
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
