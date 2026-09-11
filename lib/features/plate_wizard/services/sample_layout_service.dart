import '../models/plate_wizard_models.dart';

class SampleLayoutService {
  const SampleLayoutService();

  PlateLayoutResult generate(PlateWizardInput input) {
    if (input.samples.isEmpty) {
      return PlateLayoutResult.failure('No samples provided.');
    }
    if (input.plateRows <= 0 || input.plateCols <= 0 || input.plateCount <= 0) {
      return PlateLayoutResult.failure('Plate dimensions must be positive.');
    }

    final plates = List.generate(
      input.plateCount,
      (_) => List.generate(
        input.plateRows,
        (_) => List<WellContent?>.filled(input.plateCols, null),
      ),
    );

    String? incompleteSelectionMessage;
    for (final sample in input.samples.where(
      (candidate) => candidate.manualWells.isNotEmpty,
    )) {
      final required = sample.requiredWells(input.plateCount);
      final unique = <String>{};
      final contents = _contentsFor(sample);
      for (var index = 0; index < sample.manualWells.length; index++) {
        final position = sample.manualWells[index];
        if (!unique.add(position.key)) {
          return _failure(
            "Chosen wells for '${sample.name}' contain the same cell twice.",
            plates,
          );
        }
        if (!_isValidPosition(position, input)) {
          return _failure(
            "Chosen wells for '${sample.name}' contain a cell outside the configured plates.",
            plates,
          );
        }
        if (plates[position.plateIndex][position.row][position.column] !=
            null) {
          return _failure(
            "Chosen wells for '${sample.name}' overlap another sample.",
            plates,
          );
        }
        plates[position.plateIndex][position.row][position.column] =
            contents[index % contents.length];
      }
      if (sample.manualWells.length != required) {
        final difference = required - sample.manualWells.length;
        incompleteSelectionMessage =
            "Choose wells for '${sample.name}': $required required, ${sample.manualWells.length} selected, ${difference.abs()} ${difference >= 0 ? 'remaining' : 'too many'}.";
      }
    }

    for (final sample in input.samples.where(
      (candidate) => candidate.manualWells.isEmpty,
    )) {
      if (sample.applyToAllPlates) {
        for (final plate in plates) {
          if (!_tryPlaceSample(plate, sample)) {
            return _failure(
              "Could not fit '${sample.name}' on every plate. Change its arrangement, add plates, or choose its wells.",
              plates,
            );
          }
        }
        continue;
      }

      var placed = false;
      for (final plate in plates) {
        if (_tryPlaceSample(plate, sample)) {
          placed = true;
          break;
        }
      }
      if (!placed) {
        final (width, height) = _blockDimensions(
          sample,
          input.plateRows,
          input.plateCols,
        );
        return _failure(
          "Could not fit '${sample.name}' ($width × $height, ${sample.wellsPerPlacement} cells). Change its arrangement, add plates, or choose its wells.",
          plates,
        );
      }
    }

    if (incompleteSelectionMessage != null) {
      return _failure(incompleteSelectionMessage, plates);
    }

    return PlateLayoutResult(success: true, plates: plates);
  }

  PlateLayoutResult _failure(
    String message,
    List<List<List<WellContent?>>> plates,
  ) {
    return PlateLayoutResult.failure(message, plates: plates);
  }

  bool _isValidPosition(PlateWellPosition position, PlateWizardInput input) {
    return position.plateIndex >= 0 &&
        position.plateIndex < input.plateCount &&
        position.row >= 0 &&
        position.row < input.plateRows &&
        position.column >= 0 &&
        position.column < input.plateCols;
  }

  bool _tryPlaceSample(List<List<WellContent?>> grid, SampleSpec sample) {
    final rows = grid.length;
    final columns = grid.first.length;
    final dimensions = _dimensions(sample, rows, columns);
    final (width, height) = _blockDimensionsFrom(dimensions);
    final placementDirection = sample.sampleDirection == Direction.auto
        ? (columns >= rows ? Direction.horizontal : Direction.vertical)
        : sample.sampleDirection;
    for (var index = 0; index < rows * columns; index++) {
      final row = placementDirection == Direction.horizontal
          ? index ~/ columns
          : index % rows;
      final column = placementDirection == Direction.horizontal
          ? index % columns
          : index ~/ rows;
      if (!_canFit(grid, row, column, width, height)) continue;
      _fillBlock(grid, sample, row, column, dimensions);
      return true;
    }
    return false;
  }

  (int, int) _blockDimensions(SampleSpec sample, int rows, int columns) {
    return _blockDimensionsFrom(_dimensions(sample, rows, columns));
  }

  (int, int) _blockDimensionsFrom(
    List<({int count, Direction direction})> dimensions,
  ) {
    var width = 1;
    var height = 1;
    for (final dimension in dimensions) {
      if (dimension.direction == Direction.horizontal) {
        width *= dimension.count;
      } else {
        height *= dimension.count;
      }
    }
    return (width, height);
  }

  bool _canFit(
    List<List<WellContent?>> grid,
    int startRow,
    int startColumn,
    int width,
    int height,
  ) {
    if (startRow + height > grid.length ||
        startColumn + width > grid.first.length) {
      return false;
    }
    for (var row = startRow; row < startRow + height; row++) {
      for (var column = startColumn; column < startColumn + width; column++) {
        if (grid[row][column] != null) return false;
      }
    }
    return true;
  }

  void _fillBlock(
    List<List<WellContent?>> grid,
    SampleSpec sample,
    int startRow,
    int startColumn,
    List<({int count, Direction direction})> dimensions,
  ) {
    final horizontalStrides = <int>[];
    final verticalStrides = <int>[];
    var horizontalSize = 1;
    var verticalSize = 1;
    for (final dimension in dimensions) {
      horizontalStrides.add(horizontalSize);
      verticalStrides.add(verticalSize);
      if (dimension.direction == Direction.horizontal) {
        horizontalSize *= dimension.count;
      } else {
        verticalSize *= dimension.count;
      }
    }

    for (final combination in _indexCombinations(dimensions)) {
      var rowOffset = 0;
      var columnOffset = 0;
      for (var index = 0; index < dimensions.length; index++) {
        if (dimensions[index].direction == Direction.horizontal) {
          columnOffset += combination[index] * horizontalStrides[index];
        } else {
          rowOffset += combination[index] * verticalStrides[index];
        }
      }
      grid[startRow + rowOffset][startColumn + columnOffset] = _contentFor(
        sample,
        combination,
      );
    }
  }

  List<WellContent> _contentsFor(SampleSpec sample) {
    return _indexCombinations(
      _rawDimensions(sample),
    ).map((combination) => _contentFor(sample, combination)).toList();
  }

  WellContent _contentFor(SampleSpec sample, List<int> combination) {
    return WellContent(
      sampleName: sample.name,
      duplicateIndex: combination.first,
      variableValues: List.generate(sample.variables.length, (index) {
        final values = sample.variables[index].values;
        if (values.isEmpty) return '';
        final value = values[combination[index + 1]];
        if (value.trim().isEmpty) return '';
        final name = sample.variables[index].name.trim();
        return name.isEmpty ? value : '$name: $value';
      }),
    );
  }

  List<({int count, Direction direction})> _rawDimensions(SampleSpec sample) {
    return <({int count, Direction direction})>[
      (count: sample.duplicates, direction: sample.duplicateDirection),
      ...sample.variables.map(
        (variable) =>
            (count: variable.valueCount, direction: variable.direction),
      ),
    ];
  }

  List<({int count, Direction direction})> _dimensions(
    SampleSpec sample,
    int rows,
    int columns,
  ) {
    final dimensions = _rawDimensions(sample);
    var states =
        <
          String,
          ({
            int width,
            int height,
            List<({int count, Direction direction})> dimensions,
          })
        >{'1:1': (width: 1, height: 1, dimensions: [])};
    for (final dimension in dimensions) {
      final next =
          <
            String,
            ({
              int width,
              int height,
              List<({int count, Direction direction})> dimensions,
            })
          >{};
      final choices = dimension.direction == Direction.auto
          ? const [Direction.horizontal, Direction.vertical]
          : [dimension.direction];
      for (final state in states.values) {
        for (final direction in choices) {
          final width = direction == Direction.horizontal
              ? state.width * dimension.count
              : state.width;
          final height = direction == Direction.vertical
              ? state.height * dimension.count
              : state.height;
          next.putIfAbsent(
            '$width:$height',
            () => (
              width: width,
              height: height,
              dimensions: [
                ...state.dimensions,
                (count: dimension.count, direction: direction),
              ],
            ),
          );
        }
      }
      states = next;
    }

    List<({int count, Direction direction})>? best;
    var bestScore = double.infinity;
    for (final state in states.values) {
      final fits = state.width <= columns && state.height <= rows;
      final overflow =
          (state.width > columns ? (state.width - columns) / columns : 0) +
          (state.height > rows ? (state.height - rows) / rows : 0);
      final balance = (state.width / columns - state.height / rows).abs();
      final score = fits ? balance : 1000 + overflow + balance;
      if (score < bestScore) {
        bestScore = score;
        best = state.dimensions;
      }
    }
    return best ?? dimensions;
  }

  Iterable<List<int>> _indexCombinations(
    List<({int count, Direction direction})> dimensions,
  ) sync* {
    final indexes = List<int>.filled(dimensions.length, 0);
    while (true) {
      yield List<int>.from(indexes);
      var dimension = 0;
      while (dimension < dimensions.length) {
        indexes[dimension]++;
        if (indexes[dimension] < dimensions[dimension].count) break;
        indexes[dimension] = 0;
        dimension++;
      }
      if (dimension == dimensions.length) break;
    }
  }
}
