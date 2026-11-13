import 'package:PiliPlus/services/ai_chat/ai_chat_service.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class AiSettingController extends GetxController {
  /// reasoning_effort 可选值，界面直接显示英文协议名，
  /// 'default' 显示为「默认」且不下发该字段
  static const reasoningEffortOptions = <String>[
    'default',
    'none',
    'minimal',
    'low',
    'medium',
    'high',
    'xhigh',
    'max',
  ];

  static const defaultReasoningEffortLabel = '默认';

  static String reasoningEffortLabel(String value) =>
      value == 'default' ? defaultReasoningEffortLabel : value;

  /// 当前值在选项表中的下标，未知值回退到默认档
  static int reasoningEffortIndexOf(String value) {
    final index = reasoningEffortOptions.indexOf(value);
    return index < 0 ? 0 : index;
  }

  final enableAiChat = true.obs;
  final profiles = <Map<String, String>>[].obs;
  final activeProfile = 0.obs;
  int _modelRequest = 0;
  final model = ''.obs;
  final aiAutoScroll = true.obs;
  final reasoningEffort = 'default'.obs;
  final modelList = <String>[].obs;
  final isLoadingModels = false.obs;
  final templates = <AiPromptTemplate>[].obs;

  late final TextEditingController apiUrlCtl;
  late final TextEditingController apiKeyCtl;
  late final TextEditingController modelCtl;

  @override
  void onInit() {
    super.onInit();
    enableAiChat.value = Pref.enableAiChat;
    profiles.assignAll(Pref.aiApiProfiles);
    activeProfile.value = Pref.activeAiApiProfile;
    aiAutoScroll.value = Pref.aiAutoScroll;
    apiUrlCtl = TextEditingController();
    apiKeyCtl = TextEditingController();
    modelCtl = TextEditingController();
    _loadProfile();
    templates.value = AiChatService.getTemplates();
  }

  @override
  void onClose() {
    apiUrlCtl.dispose();
    apiKeyCtl.dispose();
    modelCtl.dispose();
    super.onClose();
  }

  void _resetModels() {
    _modelRequest++;
    modelList.clear();
    isLoadingModels.value = false;
  }

  void _loadProfile() {
    _resetModels();
    final profile = profiles[activeProfile.value];
    apiUrlCtl.text = profile['url'] ?? '';
    apiKeyCtl.text = profile['key'] ?? '';
    modelCtl.text = model.value = profile['model'] ?? '';
    final effort = profile['effort'];
    reasoningEffort.value = effort == null || effort == 'auto'
        ? 'default'
        : effort;
  }

  void _saveProfiles() => Pref.saveAiApiProfiles(profiles, activeProfile.value);

  void selectProfile(int index) {
    activeProfile.value = index;
    _saveProfiles();
    _loadProfile();
  }

  void addProfile(String name) {
    profiles.add({'name': name});
    selectProfile(profiles.length - 1);
  }

  void renameProfile(String name) => _saveProfileField('name', name);

  void deleteProfile() {
    if (profiles.length <= 1) return;
    profiles.removeAt(activeProfile.value);
    selectProfile(0);
  }

  void _saveProfileField(String key, String value) {
    final index = activeProfile.value;
    profiles[index] = {...profiles[index], key: value};
    _saveProfiles();
  }

  Future<void> fetchModels() async {
    final request = ++_modelRequest;
    isLoadingModels.value = true;
    try {
      final models = await AiChatService.fetchModels();
      if (isClosed || request != _modelRequest) return;
      modelList.value = models;
      if (models.isEmpty) {
        SmartDialog.showToast('未获取到模型列表，请检查 API 配置');
      }
    } catch (e) {
      if (!isClosed && request == _modelRequest) {
        SmartDialog.showToast('获取模型列表失败: $e');
      }
    } finally {
      if (!isClosed && request == _modelRequest) {
        isLoadingModels.value = false;
      }
    }
  }

  void saveApiUrl(String value) {
    _resetModels();
    _saveProfileField('url', value);
  }

  void saveApiKey(String value) {
    _resetModels();
    _saveProfileField('key', value);
  }

  void saveModel(String value) {
    if (modelCtl.text != value) modelCtl.text = value;
    model.value = value;
    _saveProfileField('model', value);
  }

  void saveAiAutoScroll(bool value) {
    aiAutoScroll.value = value;
    Pref.aiAutoScroll = value;
  }

  void saveReasoningEffort(String value) {
    reasoningEffort.value = value;
    _saveProfileField('effort', value);
  }

  void addTemplate(String name, String prompt) {
    templates.add(AiPromptTemplate(name: name, prompt: prompt));
    _saveTemplates();
  }

  void updateTemplate(int index, String name, String prompt) {
    templates[index] = AiPromptTemplate(name: name, prompt: prompt);
    templates.refresh();
    _saveTemplates();
  }

  void deleteTemplate(int index) {
    templates.removeAt(index);
    _saveTemplates();
  }

  void reorderTemplate(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final item = templates.removeAt(oldIndex);
    templates.insert(newIndex, item);
    _saveTemplates();
  }

  void restoreDefaults() {
    templates.value = List.from(AiChatService.defaultTemplates);
    _saveTemplates();
  }

  void _saveTemplates() {
    AiChatService.saveTemplates(templates);
  }
}
