/**
 * 全局配置
 * 定义页面路由、窗口表现、tabBar 等
 */
export default defineAppConfig({
  pages: [
    'pages/auth/login/index',     // 登录页
    'pages/auth/onboarding/index', // 家庭引导（首次登录无家庭时跳转）
    'pages/home/index',            // 首页
    'pages/medication/index',     // 药品管理
    'pages/calendar/index',        // 日历
    'pages/care-log/index',       // 护理日志
    'pages/family/index',         // 家庭
    'pages/profile/index',        // 个人设置
    'pages/sos/index',           // SOS 紧急
    'pages/notification/index',   // 通知列表
    'pages/daily-care/index',      // 每日护理打卡
    'pages/care-recipient/add', // 添加照护对象
    'pages/care-recipient/detail', // 照护对象详情
    'pages/medication/detail', // 药品详情
    'pages/family-task/add',   // 添加任务
    'pages/appointment/add',   // 添加复诊
  ],
  window: {
    backgroundTextStyle: 'light',
    navigationBarBackgroundColor: '#7B9E87',
    navigationBarTitleText: '一家护',
    navigationBarTextStyle: 'white',
    backgroundColor: '#FAF9F7',
  },
  tabBar: {
    color: '#B0ADAD',
    selectedColor: '#7B9E87',
    backgroundColor: '#FFFFFF',
    borderStyle: 'white',
    list: [
      {
        pagePath: 'pages/home/index',
        text: '首页',
        iconPath: 'assets/tabbar/home.png',
        selectedIconPath: 'assets/tabbar/home-active.png',
      },
      {
        pagePath: 'pages/calendar/index',
        text: '日历',
        iconPath: 'assets/tabbar/calendar.png',
        selectedIconPath: 'assets/tabbar/calendar-active.png',
      },
      {
        pagePath: 'pages/care-log/index',
        text: '日志',
        iconPath: 'assets/tabbar/log.png',
        selectedIconPath: 'assets/tabbar/log-active.png',
      },
      {
        pagePath: 'pages/family/index',
        text: '家庭',
        iconPath: 'assets/tabbar/family.png',
        selectedIconPath: 'assets/tabbar/family-active.png',
      },
      {
        pagePath: 'pages/profile/index',
        text: '我的',
        iconPath: 'assets/tabbar/profile.png',
        selectedIconPath: 'assets/tabbar/profile-active.png',
      },
    ],
  },
  permission: {
    'scope.userLocation': {
      desc: '用于 SOS 紧急求助时获取您的位置信息',
    },
  },
  requiredPrivateInfos: ['chooseAddress', 'getLocation'],
});
