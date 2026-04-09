export default {
  projectName: 'yijiahu-miniprogram',
  date: new Date().toISOString(),
  designWidth: 375,
  deviceRatio: {
    640: 2.34 / 2,
    750: 1 / 2,
    828: 1.81 / 2,
    375: 2 / 2,
  },
  sourceRoot: 'src',
  outputRoot: 'dist',
  plugins: [
    '@tarojs/plugin-platform-weapp',
    '@tarojs/plugin-framework-react',
  ],
  framework: 'react',
  compiler: 'webpack5',
  weapp: {
    compile: {
      compress: true,
    },
  },
  defineConstants: {
    // 环境变量 API_BASE_URL 控制，默认 localhost
    API_BASE_URL: JSON.stringify(process.env.API_BASE_URL || 'http://127.0.0.1:3000/v1'),
  },
};
