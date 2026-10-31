import 'package:flutter/material.dart';

/// Shown when every sticker is filled but the state breaks the cube's
/// physical rules (twisted corner, flipped edge, swapped pieces, ...).
Future<void> showUnsolvableDialog(BuildContext context, List<String> reasons) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded,
            size: 40, color: Colors.amber),
        title: const Text('填色状态不可解'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final r in reasons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $r',
                      style: TextStyle(color: theme.colorScheme.error)),
                ),
              const SizedBox(height: 8),
              const Text('请检查：', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('1. 是否有色块填错了——旋转屏幕上的魔方，逐面和实体魔方核对，'
                  '尤其注意角块和棱块上相邻的颜色。'),
              const SizedBox(height: 4),
              const Text('2. 实体魔方是否被暴力拆装过——单个角块被拧转、单个棱块被翻转或'
                  '两个块装反，都会导致魔方在物理上无法还原，需要先把它拆下装回正确方向。'),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('返回检查'),
          ),
        ],
      );
    },
  );
}
