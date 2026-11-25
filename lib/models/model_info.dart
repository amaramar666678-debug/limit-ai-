class ModelOption {
  const ModelOption({
    required this.id,
    required this.name,
    required this.providerID,
    this.family,
    this.context,
    this.output,
    this.variants = const [],
    this.input = const [],
    this.remote = false,
  });

  final String id;
  final String name;
  final String providerID;
  final String? family;
  final int? context;
  final int? output;
  final List<String> variants;
  final List<String> input;
  final bool remote;

  String get key => '$providerID/$id';

  String get shortName {
    final n = name.trim();
    if (n.isEmpty) return id;
    return n.length > 28 ? '${n.substring(0, 27)}…' : n;
  }

  factory ModelOption.fromJson(Map<String, dynamic> j) {
    final id = (j['id'] ?? j['modelID'] ?? '').toString();
    final provider = (j['providerID'] ?? 'opencode').toString();
    final variants = <String>[];
    final rawVariants = j['variants'];
    if (rawVariants is List) {
      for (final v in rawVariants) {
        if (v is Map && v['id'] != null) variants.add(v['id'].toString());
      }
    }
    final rawInput = j['capabilities'] is Map ? (j['capabilities'] as Map)['input'] : null;
    final input = <String>[];
    if (rawInput is List) {
      for (final v in rawInput) {
        input.add(v.toString());
      }
    }
    final limit = j['limit'] is Map ? j['limit'] as Map : const {};
    return ModelOption(
      id: id,
      providerID: provider,
      name: (j['name'] ?? id).toString(),
      family: j['family']?.toString(),
      context: _intOf(limit['context'] ?? j['context']),
      output: _intOf(limit['output'] ?? j['output']),
      variants: variants,
      input: input,
      remote: true,
    );
  }

  static int? _intOf(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static const fallback = <ModelOption>[
    ModelOption(id: 'big-pickle', name: 'Big Pickle', providerID: 'opencode', context: 200000, output: 32000),
    ModelOption(id: 'deepseek-v4.1-flash-free', name: 'DeepSeek V4.1 Flash Free', providerID: 'opencode', context: 200000, output: 32000, variants: ['low', 'high', 'max']),
    ModelOption(id: 'tidepool-alpha-free', name: 'Tidepool Alpha Free', providerID: 'opencode', context: 1048576, output: 131072, variants: ['minimal', 'low', 'medium', 'high', 'xhigh', 'max']),
    ModelOption(id: 'hy4-flash-free', name: 'Hy4 Flash Free', providerID: 'opencode', context: 1048576, output: 65536, variants: ['none', 'high']),
  ];
}
