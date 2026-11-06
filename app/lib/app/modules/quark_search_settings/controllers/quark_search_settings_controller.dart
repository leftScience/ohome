import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/api/config.dart';
import '../../../data/models/config_model.dart';
import '../../../data/models/config_upsert_payload.dart';
import '../../../data/models/pan_web_engine.dart';
import '../views/quark_tag_editor_view.dart';
import '../views/quark_web_engine_editor_view.dart';

class QuarkSearchSettingsController extends GetxController {
  QuarkSearchSettingsController({ConfigApi? configApi})
    : _configApi = configApi ?? Get.find<ConfigApi>();

  static const String httpProxyKey = 'quark_search_http_proxy';
  static const String httpsProxyKey = 'quark_search_https_proxy';
  static const String channelsKey = 'quark_search_channels';
  static const String enabledPluginsKey = 'quark_search_enabled_plugins';
  static const String webEnginesKey = 'quark_search_web_engines';
  static const String defaultChannelsValue =
      'tgsearchers4,Aliyun_4K_Movies,bdbdndn11,yunpanx,bsbdbfjfjff,yp123pan,sbsbsnsqq,yunpanxunlei,tianyifc,BaiduCloudDisk,txtyzy,peccxinpd,gotopan,PanjClub,kkxlzy,baicaoZY,MCPH01,MCPH02,MCPH03,bdwpzhpd,ysxb48,jdjdn1111,yggpan,MCPH086,zaihuayun,Q66Share,ucwpzy,shareAliyun,alyp_1,dianyingshare,Quark_Movies,XiangxiuNBB,ydypzyfx,ucquark,xx123pan,yingshifenxiang123,zyfb123,tyypzhpd,tianyirigeng,cloudtianyi,hdhhd21,Lsp115,oneonefivewpfx,qixingzhenren,taoxgzy,Channel_Shares_115,tyysypzypd,vip115hot,wp123zy,yunpan139,yunpan189,yunpanuc,yydf_hzl,leoziyuan,Q_dongman,yoyokuakeduanju,TG654TG,WFYSFX02,QukanMovie,yeqingjie_GJG666,movielover8888_film3,Baidu_netdisk,D_wusun,FLMdongtianfudi,KaiPanshare,QQZYDAPP,rjyxfx,PikPak_Share_Channel,btzhi,newproductsourcing,cctv1211,duan_ju,QuarkFree,yunpanNB,kkdj001,xxzlzn,pxyunpanxunlei,jxwpzy,kuakedongman,liangxingzhinan,xiangnikanj,solidsexydoll,guoman4K,zdqxm,kduanju,cilidianying,CBduanju,SharePanFilms,dzsgx,BooksRealm,Oscar_4Kmovies,douerpan,baidu_yppan,Q_jilupian,Netdisk_Movies,yunpanquark,ammmziyuan,ciliziyuanku,cili8888,jzmm_123pan,Q_dianying,domgmingapk,dianying4k,q_dianshiju,tgbokee,ucshare,godupan,gokuapan';
  static const String defaultEnabledPluginsValue =
      'ddys,erxiao,hdr4k,jutoushe,labi,libvio,lou1,panta,susu,wanou,xuexizhinan,zhizhen,ahhhhfs,alupan,ash,clxiong,discourse,djgou,duoduo,dyyj,hdmoli,huban,jsnoteclub,kkmao,leijing,meitizy,mikuclub,muou,nsgame,ouge,panyq,shandian,xinjuc,ypfxw,yunsou,aikanzy,bixin,cldi,clmao,cyg,daishudj,feikuai,fox4k,haisou,hunhepan,jikepan,kkv,miaoso,mizixing,nyaa,pan666,pansearch,panwiki,pianku,qingying,quark4k,quarksoo,qupanshe,qupansou,sdso,sousou,wuji,xb6v,xdpan,xdyh,xiaoji,xiaozhang,xys,yiove,zxzj';

  final ConfigApi _configApi;

  final loading = false.obs;
  final saving = false.obs;
  final configs = <String, ConfigModel>{}.obs;
  final selectedChannels = <String>[].obs;
  final selectedPlugins = <String>[].obs;
  final webEngines = <PanWebEngine>[].obs;

  final httpProxyController = TextEditingController();
  final httpsProxyController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    loadConfigs();
  }

  @override
  void onClose() {
    httpProxyController.dispose();
    httpsProxyController.dispose();
    super.onClose();
  }

  Future<void> loadConfigs() async {
    loading.value = true;
    try {
      final result = await _configApi.findConfigsByKeys(_configKeys);
      configs.assignAll(result);
      httpProxyController.text = result[httpProxyKey]?.value.trim() ?? '';
      httpsProxyController.text = result[httpsProxyKey]?.value.trim() ?? '';
      selectedChannels.assignAll(
        _parseTags(_channelsValue(result[channelsKey])),
      );
      selectedPlugins.assignAll(
        _parseTags(_pluginsValue(result[enabledPluginsKey])),
      );
      webEngines.assignAll(
        PanWebEngine.parseConfigValue(result[webEnginesKey]?.value),
      );
    } finally {
      loading.value = false;
    }
  }

  Future<void> save() async {
    if (saving.value) return;

    saving.value = true;
    try {
      await _saveSingle(
        key: httpProxyKey,
        name: '夸克搜索 HTTP 代理',
        remark: 'HTTP 请求代理地址，留空则直连',
        value: httpProxyController.text.trim(),
      );
      await _saveSingle(
        key: httpsProxyKey,
        name: '夸克搜索 HTTPS 代理',
        remark: 'HTTPS 请求代理地址，留空则直连',
        value: httpsProxyController.text.trim(),
      );
      await _saveSingle(
        key: channelsKey,
        name: '夸克搜索 TG 频道',
        remark: '默认搜索 TG 频道，多个频道使用逗号分隔',
        value: _joinTags(selectedChannels),
      );
      await _saveSingle(
        key: enabledPluginsKey,
        name: '夸克搜索 启用插件',
        remark: '指定启用插件，多个插件使用逗号分隔',
        value: _joinTags(selectedPlugins),
      );
      await _saveSingle(
        key: webEnginesKey,
        name: '夸克搜索 自定义搜索源',
        remark: '自定义网盘 Web 搜索源 JSON：[{name,url}]，url 使用 {kw} 占位关键词',
        value: PanWebEngine.serializeConfigValue(webEngines.toList()),
      );
      await loadConfigs();
      Get.snackbar('提示', '夸克搜索配置已保存');
    } finally {
      saving.value = false;
    }
  }

  DateTime? updatedAtFor(String key) => configs[key]?.updatedAt;

  String get supportedPluginsHint => '系统已预置常用插件清单，也可以补充自定义插件标签。';

  Future<void> openChannelsEditor() async {
    final result = await Get.to<List<String>>(
      () => QuarkTagEditorView(
        title: '编辑 TG 频道',
        description:
            '默认搜索时会在这些 Telegram 频道中检索资源。'
            '你可以选中、取消选中，也可以新增或删除频道标签。',
        inputHint: '输入频道名后点击新增',
        addButtonText: '新增频道',
        emptyStateText: '还没有频道标签，先新增一个吧。',
        initialOptions: _mergeTagOptions(
          selectedChannels,
          _parseTags(defaultChannelsValue),
        ),
        initialSelected: selectedChannels,
      ),
    );
    if (result != null) {
      selectedChannels.assignAll(result);
    }
  }

  Future<void> openPluginsEditor() async {
    final result = await Get.to<List<String>>(
      () => QuarkTagEditorView(
        title: '编辑插件',
        description:
            '选择夸克搜索启用的插件。'
            '你可以按标签选择、取消选择，也可以新增或删除插件标签。',
        inputHint: '输入插件名后点击新增',
        addButtonText: '新增插件',
        emptyStateText: '还没有插件标签，先新增一个吧。',
        initialOptions: _mergeTagOptions(
          selectedPlugins,
          _parseTags(defaultEnabledPluginsValue),
        ),
        initialSelected: selectedPlugins,
      ),
    );
    if (result != null) {
      selectedPlugins.assignAll(result);
    }
  }

  Future<void> addWebEngine() async {
    final result = await Get.to<PanWebEngine>(
      () => const QuarkWebEngineEditorView(),
    );
    if (result == null) return;
    webEngines.add(
      PanWebEngine(
        id: _nextWebEngineId(),
        name: result.name,
        urlTemplate: result.urlTemplate,
      ),
    );
  }

  Future<void> editWebEngine(int index) async {
    if (index < 0 || index >= webEngines.length) return;
    final result = await Get.to<PanWebEngine>(
      () => QuarkWebEngineEditorView(initial: webEngines[index]),
    );
    if (result == null) return;
    webEngines[index] = result;
  }

  void removeWebEngine(int index) {
    if (index < 0 || index >= webEngines.length) return;
    webEngines.removeAt(index);
  }

  String _nextWebEngineId() {
    final used = webEngines.map((engine) => engine.id).toSet();
    var index = webEngines.length;
    while (used.contains('web_$index')) {
      index++;
    }
    return 'web_$index';
  }

  Future<void> _saveSingle({
    required String key,
    required String name,
    required String remark,
    required String value,
  }) async {
    final existing = configs[key];
    final payload = existing != null
        ? ConfigUpsertPayload.fromConfig(existing, value: value)
        : ConfigUpsertPayload(
            name: name,
            key: key,
            value: value,
            isLock: '1',
            remark: remark,
          );
    await _configApi.saveConfig(payload);
  }

  String _channelsValue(ConfigModel? config) {
    if (config == null) return defaultChannelsValue;
    return config.value.trim();
  }

  String _pluginsValue(ConfigModel? config) {
    if (config == null) return defaultEnabledPluginsValue;
    return config.value.trim();
  }

  List<String> _mergeTagOptions(
    Iterable<String> preferred,
    Iterable<String> fallback,
  ) {
    return _parseTags(<String>[...preferred, ...fallback].join(','));
  }

  List<String> _parseTags(String raw) {
    final result = <String>[];
    final seen = <String>{};
    for (final part in raw.split(',')) {
      final value = part.trim();
      if (value.isEmpty) continue;
      final normalized = value.toLowerCase();
      if (!seen.add(normalized)) continue;
      result.add(value);
    }
    return result;
  }

  String _joinTags(Iterable<String> values) {
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join(',');
  }

  List<String> get _configKeys => const <String>[
    httpProxyKey,
    httpsProxyKey,
    channelsKey,
    enabledPluginsKey,
    webEnginesKey,
  ];
}
