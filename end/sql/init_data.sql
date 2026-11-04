INSERT INTO `sys_dict_type` (
    id,
    name,
    `key`,
    status,
    remark,
    created_at,
    updated_at,
    deleted_at
) VALUES
    (13, '上传文件类型', 'uploadFileType', '1', '文件上传类型选项', '2026-03-20 00:00:00', '2026-03-20 00:00:00', NULL);

INSERT INTO `sys_dict_data` (
    id,
    sort,
    label,
    label_en,
    value,
    dict_type,
    is_default,
    status,
    remark,
    created_at,
    updated_at,
    deleted_at
) VALUES
    (43, 1, '用户头像', 'userAvatar', 'userAvatar', 'uploadFileType', 'Y', '1', '用户头像上传类型', '2026-03-20 00:00:00', '2026-03-20 00:00:00', NULL);

INSERT INTO `sys_quark_config` (
    created_at,
    updated_at,
    deleted_at,
    root_path,
    remark,
    application
) VALUES
    ('2025-12-24 13:09:33.977', '2026-03-06 14:52:27.735', NULL, 'WP/VEDIO', '影视', 'tv'),
    ('2025-12-25 13:43:30.451', '2025-12-25 13:43:30.451', NULL, 'WP/MUSIC', '播客', 'music'),
    ('2025-12-25 13:43:30.451', '2025-12-25 13:43:30.451', NULL, 'WP/READ', '阅读', 'read'),
    ('2025-12-25 13:43:30.451', '2025-12-25 13:43:30.451', NULL, 'WP/PLAYLET', '短剧', 'playlet'),
    ('2025-12-25 13:43:30.451', '2025-12-25 13:43:30.451', NULL, 'WP/UPLOAD', '文件上传', 'upload');

INSERT INTO `sys_config` (
    created_at,
    updated_at,
    deleted_at,
    name,
    `key`,
    `value`,
    is_lock,
    remark
) VALUES
    ('2026-03-20 00:00:00', '2026-03-20 00:00:00', NULL, '夸克账户共享状态', 'quark_account_share_mode', 'shared', '1', 'shared=共享夸克账号；exclusive=强制全员独享'),
    ('2026-03-20 00:00:00', '2026-03-20 00:00:00', NULL, '夸克播放代理模式', 'quark_fs_web_proxy_mode', 'native_proxy', '1', '夸克在线播放代理模式：native_proxy=本地代理，302_redirect=302直连'),
    ('2026-03-20 00:00:00', '2026-03-20 00:00:00', NULL, '夸克搜索 HTTP 代理', 'quark_search_http_proxy', '', '1', 'HTTP 请求代理地址，留空则直连'),
    ('2026-03-20 00:00:00', '2026-03-20 00:00:00', NULL, '夸克搜索 HTTPS 代理', 'quark_search_https_proxy', '', '1', 'HTTPS 请求代理地址，留空则直连'),
    ('2026-03-20 00:00:00', '2026-03-20 00:00:00', NULL, '夸克搜索 TG 频道', 'quark_search_channels', 'tgsearchers4,Aliyun_4K_Movies,bdbdndn11,yunpanx,bsbdbfjfjff,yp123pan,sbsbsnsqq,yunpanxunlei,tianyifc,BaiduCloudDisk,txtyzy,peccxinpd,gotopan,PanjClub,kkxlzy,baicaoZY,MCPH01,MCPH02,MCPH03,bdwpzhpd,ysxb48,jdjdn1111,yggpan,MCPH086,zaihuayun,Q66Share,ucwpzy,shareAliyun,alyp_1,dianyingshare,Quark_Movies,XiangxiuNBB,ydypzyfx,ucquark,xx123pan,yingshifenxiang123,zyfb123,tyypzhpd,tianyirigeng,cloudtianyi,hdhhd21,Lsp115,oneonefivewpfx,qixingzhenren,taoxgzy,Channel_Shares_115,tyysypzypd,vip115hot,wp123zy,yunpan139,yunpan189,yunpanuc,yydf_hzl,leoziyuan,Q_dongman,yoyokuakeduanju,TG654TG,WFYSFX02,QukanMovie,yeqingjie_GJG666,movielover8888_film3,Baidu_netdisk,D_wusun,FLMdongtianfudi,KaiPanshare,QQZYDAPP,rjyxfx,PikPak_Share_Channel,btzhi,newproductsourcing,cctv1211,duan_ju,QuarkFree,yunpanNB,kkdj001,xxzlzn,pxyunpanxunlei,jxwpzy,kuakedongman,liangxingzhinan,xiangnikanj,solidsexydoll,guoman4K,zdqxm,kduanju,cilidianying,CBduanju,SharePanFilms,dzsgx,BooksRealm,Oscar_4Kmovies,douerpan,baidu_yppan,Q_jilupian,Netdisk_Movies,yunpanquark,ammmziyuan,ciliziyuanku,cili8888,jzmm_123pan,Q_dianying,domgmingapk,dianying4k,q_dianshiju,tgbokee,ucshare,godupan,gokuapan', '1', '默认搜索 TG 频道，多个频道用逗号分隔'),
    ('2026-03-20 00:00:00', '2026-03-20 00:00:00', NULL, '夸克搜索 启用插件', 'quark_search_enabled_plugins', 'ddys,erxiao,hdr4k,jutoushe,labi,libvio,lou1,panta,susu,wanou,xuexizhinan,zhizhen,ahhhhfs,alupan,ash,clxiong,discourse,djgou,duoduo,dyyj,hdmoli,huban,jsnoteclub,kkmao,leijing,meitizy,mikuclub,muou,nsgame,ouge,panyq,shandian,xinjuc,ypfxw,yunsou,aikanzy,bixin,cldi,clmao,cyg,daishudj,feikuai,fox4k,haisou,hunhepan,jikepan,kkv,miaoso,mizixing,nyaa,pan666,pansearch,panwiki,pianku,qingying,quark4k,quarksoo,qupanshe,qupansou,sdso,sousou,wuji,xb6v,xdpan,xdyh,xiaoji,xiaozhang,xys,yiove,zxzj', '1', '指定启用插件，多个插件用逗号分隔');

INSERT INTO `sys_role` (
    id,
    created_at,
    updated_at,
    deleted_at,
    name,
    code,
    remark
) VALUES
    (1, '2026-03-14 11:56:24', '2026-03-14 11:56:24', NULL, '超级管理员', 'super_admin', '拥有用户管理和夸克登录设置权限'),
    (2, '2026-03-14 11:56:24', '2026-03-14 11:56:24', NULL, '普通用户', 'user', '普通业务用户');

INSERT INTO `sys_user` (
    id,
    created_at,
    updated_at,
    deleted_at,
    name,
    real_name,
    avatar,
    password,
    role_id
) VALUES
    (
        1,
        '2024-05-23 21:43:37',
        '2026-03-08 11:08:18',
        NULL,
        'admin',
        'admin',
        '',
        '$2a$10$JqSqmK8db/16SFkX9vb8hO0CLGtCVBI0GHWOXU/QK9r9df.kqXE16',
        1
    );
