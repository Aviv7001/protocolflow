import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;

import '../services/protocol_image_processing_service.dart';
import '../theme/app_colors.dart';

class ProtocolImageEditResult {
  const ProtocolImageEditResult({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

class ProtocolImageEditorDialog extends StatefulWidget {
  const ProtocolImageEditorDialog({
    super.key,
    required this.imageBytes,
    required this.initialName,
  });

  final Uint8List imageBytes;
  final String initialName;

  @override
  State<ProtocolImageEditorDialog> createState() =>
      _ProtocolImageEditorDialogState();
}

class _ProtocolImageEditorDialogState extends State<ProtocolImageEditorDialog> {
  late final TextEditingController _nameController;
  late ProtocolImageLayoutMode _mode;
  double _focusX = 0.5;
  double _focusY = 0.5;
  double _zoom = 1;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    final decoded = image.decodeImage(widget.imageBytes);
    final aspectRatio = decoded == null ? 0.75 : decoded.width / decoded.height;
    _mode = aspectRatio > 0.75
        ? ProtocolImageLayoutMode.fit
        : ProtocolImageLayoutMode.crop;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final bytes = ProtocolImageProcessingService.createThreeByFourImage(
        widget.imageBytes,
        mode: _mode,
        focusX: _focusX,
        focusY: _focusY,
        zoom: _zoom,
      );
      if (!mounted) return;
      Navigator.pop(context, ProtocolImageEditResult(name: name, bytes: bytes));
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not prepare image: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cropMode = _mode == ProtocolImageLayoutMode.crop;
    final preview = Container(
      color: Colors.white,
      child: ClipRect(
        child: cropMode
            ? Transform.scale(
                scale: _zoom,
                child: Image.memory(
                  widget.imageBytes,
                  fit: BoxFit.cover,
                  alignment: Alignment((_focusX * 2) - 1, (_focusY * 2) - 1),
                ),
              )
            : Image.memory(widget.imageBytes, fit: BoxFit.contain),
      ),
    );

    return AlertDialog(
      title: const Text('Crop and rename image'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 460),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.outline),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: preview,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('protocol-image-name-field'),
                controller: _nameController,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Image name',
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<ProtocolImageLayoutMode>(
                segments: const [
                  ButtonSegment(
                    value: ProtocolImageLayoutMode.fit,
                    icon: Icon(Icons.fit_screen_outlined),
                    label: Text('Fit'),
                  ),
                  ButtonSegment(
                    value: ProtocolImageLayoutMode.crop,
                    icon: Icon(Icons.crop_outlined),
                    label: Text('Crop'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) {
                  setState(() => _mode = selection.first);
                },
              ),
              const SizedBox(height: 8),
              Text(
                cropMode
                    ? 'Adjust the crop position and zoom. The saved figure is always 3:4.'
                    : 'The full image is centered and any gaps are filled with white.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              if (cropMode) ...[
                const SizedBox(height: 8),
                _buildSlider(
                  label: 'Horizontal position',
                  value: _focusX,
                  onChanged: (value) => setState(() => _focusX = value),
                ),
                _buildSlider(
                  label: 'Vertical position',
                  value: _focusY,
                  onChanged: (value) => setState(() => _focusY = value),
                ),
                _buildSlider(
                  label: 'Zoom',
                  value: _zoom,
                  min: 1,
                  max: 3,
                  onChanged: (value) => setState(() => _zoom = value),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    double min = 0,
    double max = 1,
  }) {
    return Row(
      children: [
        SizedBox(width: 132, child: Text(label)),
        Expanded(
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }
}
