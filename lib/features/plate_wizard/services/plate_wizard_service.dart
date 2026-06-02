import '../models/plate_wizard_models.dart';

class PlateWizardService {
  PlateLayoutResult generatePlateLayout(PlateWizardInput input) {
    if (input.samples.isEmpty) {
      return PlateLayoutResult.failure("No samples provided.");
    }

    List<List<List<WellContent?>>> plates = [];
    
    _addNewPlate(plates, input);

    for (var sample in input.samples) {
      // Calculate individual block dimensions for THIS specific sample
      int nCond = sample.conditions.length;
      int nDil = sample.dilutions.length;
      int nRep = sample.duplicates;

      int bWidth = 1;
      int bHeight = 1;

      if (input.duplicateDirection == Direction.horizontal) {
        bWidth *= nRep;
      } else {
        bHeight *= nRep;
      }
      if (input.dilutionDirection == Direction.horizontal) {
        bWidth *= nDil;
      } else {
        bHeight *= nDil;
      }
      if (input.conditionDirection == Direction.horizontal) {
        bWidth *= nCond;
      } else {
        bHeight *= nCond;
      }

      bool placed = false;
      
      // Try to place on existing plates first
      for (int pIdx = 0; pIdx < plates.length; pIdx++) {
        var grid = plates[pIdx];
        if (_tryPlaceSample(grid, input, sample, bWidth, bHeight)) {
          placed = true;
          break;
        }
      }

      // If not placed, try adding a NEW plate
      if (!placed) {
        var newGrid = _addNewPlate(plates, input);
        if (_tryPlaceSample(newGrid, input, sample, bWidth, bHeight)) {
          placed = true;
        }
      }

      if (!placed) {
        return PlateLayoutResult.failure(
            "Could not fit sample '${sample.name}' even on a fresh plate. Block dimensions ($bWidth x $bHeight) exceed plate size.");
      }
    }

    return PlateLayoutResult(
      success: true,
      plates: plates,
    );
  }

  List<List<WellContent?>> _addNewPlate(List<List<List<WellContent?>>> plates, PlateWizardInput input) {
    List<List<WellContent?>> grid = List.generate(
      input.plateRows,
      (_) => List.generate(input.plateCols, (_) => null),
    );
    plates.add(grid);
    return grid;
  }

  bool _tryPlaceSample(List<List<WellContent?>> grid, PlateWizardInput input, SampleSpec sample, int bWidth, int bHeight) {
    int totalPlateWells = input.plateRows * input.plateCols;
    for (int i = 0; i < totalPlateWells; i++) {
      int r, c;
      if (input.sampleDirection == Direction.horizontal) {
        r = i ~/ input.plateCols;
        c = i % input.plateCols;
      } else {
        c = i ~/ input.plateRows;
        r = i % input.plateRows;
      }

      if (_canFitBlock(grid, r, c, bWidth, bHeight, input.plateRows, input.plateCols)) {
        _fillSampleBlock(grid, input, sample, r, c);
        return true;
      }
    }
    return false;
  }

  bool _canFitBlock(List<List<WellContent?>> grid, int startR, int startC, int bW, int bH, int maxR, int maxC) {
    if (startR + bH > maxR || startC + bW > maxC) return false;
    for (int r = startR; r < startR + bH; r++) {
      for (int c = startC; c < startC + bW; c++) {
        if (grid[r][c] != null) return false;
      }
    }
    return true;
  }

  void _fillSampleBlock(List<List<WellContent?>> grid, PlateWizardInput input, SampleSpec sample, int startR, int startC) {
    int nCond = sample.conditions.length;
    int nDil = sample.dilutions.length;
    int nRep = sample.duplicates;

    // Multipliers for offsets
    int dilBlockW = input.duplicateDirection == Direction.horizontal ? nRep : 1;
    int dilBlockH = input.duplicateDirection == Direction.vertical ? nRep : 1;

    int condBlockW = dilBlockW * (input.dilutionDirection == Direction.horizontal ? nDil : 1);
    int condBlockH = dilBlockH * (input.dilutionDirection == Direction.vertical ? nDil : 1);

    for (int cIdx = 0; cIdx < nCond; cIdx++) {
      for (int dIdx = 0; dIdx < nDil; dIdx++) {
        for (int rIdx = 0; rIdx < nRep; rIdx++) {
          int relC = 0;
          int relR = 0;

          if (input.duplicateDirection == Direction.horizontal) {
            relC += rIdx;
          } else {
            relR += rIdx;
          }

          if (input.dilutionDirection == Direction.horizontal) {
            relC += dIdx * dilBlockW;
          } else {
            relR += dIdx * dilBlockH;
          }

          if (input.conditionDirection == Direction.horizontal) {
            relC += cIdx * condBlockW;
          } else {
            relR += cIdx * condBlockH;
          }

          grid[startR + relR][startC + relC] = WellContent(
            sampleName: sample.name,
            conditionIndex: cIdx,
            conditionName: sample.conditions[cIdx],
            dilutionIndex: dIdx,
            dilutionName: sample.dilutions[dIdx],
            duplicateIndex: rIdx,
          );
        }
      }
    }
  }
}
