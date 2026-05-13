/**
 * WebView 页面
 * 用于在小程序内打开外部网页（隐私政策、用户协议等）
 */
import { WebView } from '@tarojs/components';
import Taro, { useRouter } from '@tarojs/taro';

export default function WebviewPage() {
  const router = useRouter();
  const url = router.params.url || 'https://yijiahu.com.cn';

  return <WebView src={url} />;
}
