import '../models/material.dart';
import '../models/protocol.dart';
import '../models/protocol_step.dart';
import '../models/protocol_table.dart';

List<Protocol> getMockProtocols() {
  final stainingTable = ProtocolTable(
    id: 'table_staining_1',
    title: 'Lectin Staining Matrix',
    type: TableType.reagentMatrix,
    columnHeaders: ['Sample', 'Lectin', 'Volume (µL)', 'Buffer (µL)'],
    data: [
      ['THP1 - SNA', 'SNA-Biotin', '2', '98'],
      ['THP1 - MAL', 'MAL-II-Biotin', '2', '98'],
      ['PBMC Control', 'CD45-APC', '5', '95'],
    ],
  );

  final plateLayout = ProtocolTable(
    id: 'table_plate_1',
    title: '96-Well Plate Layout',
    type: TableType.plateLayout,
    columnHeaders: ['1', '2', '3', '4', '5'],
    rowHeaders: ['A', 'B', 'C'],
    data: [
      ['THP1+SNA', 'THP1+SNA', 'THP1+SNA', 'Empty', 'Empty'],
      ['THP1+MAL', 'THP1+MAL', 'THP1+MAL', 'Empty', 'Empty'],
      ['PBMC', 'PBMC', 'PBMC', 'Empty', 'Empty'],
    ],
    metadata: {'plateSize': '96'},
  );

  final detectionTable = ProtocolTable(
    id: 'table_detection_1',
    title: 'Detection Table',
    type: TableType.checklist,
    columnHeaders: ['Reagent', 'Concentration', 'Incubation', 'Checked'],
    data: [
      ['Streptavidin-APC', '1:200', '30 min', false],
      ['DAPI', '1:1000', '5 min', false],
    ],
  );

  final unassignedTable = ProtocolTable(
    id: 'table_reference_1',
    title: 'Buffer Reference Table',
    type: TableType.generic,
    columnHeaders: ['Buffer', 'Composition', 'Storage'],
    data: [
      ['FACS Buffer', 'PBS + 2% FBS + 1mM EDTA', '4°C'],
      ['Blocking Buffer', 'FACS Buffer + 1% Fish Gelatin', '4°C'],
    ],
  );

  final thp1Protocol = Protocol(
    id: '041626_AY_1',
    title: 'Lectin Flow Cytometry for THP1 cells (AML)',
    objective:
        'Identify AML associated sialoglycans using flow cytometry with lectin panel',
    description:
        'Using THP1 cells and lectins SNA (a2-6) and MAL-II (a2-3). PBMC used as control with CD45 marker.',
    materials: [
      MaterialItem(
        id: 'm1',
        name: 'PBS',
        quantity: 'As needed',
        catalogNumber: '14190-144',
        manufacturer: 'Gibco',
        location: 'Cold Room',
        stockConcentration: '10X',
      ),
      MaterialItem(
        id: 'm2',
        name: 'Fish Gelatin',
        quantity: 'As needed',
        catalogNumber: 'G7041',
        manufacturer: 'Sigma',
        location: 'Shelf B2',
        stockConcentration: '100%',
      ),
      MaterialItem(
        id: 'm3',
        name: 'EDTA',
        quantity: 'As needed',
        catalogNumber: 'E9884',
        manufacturer: 'Sigma',
        location: 'Shelf B2',
        stockConcentration: '0.5M',
      ),
      MaterialItem(
        id: 'm4',
        name: 'DAPI',
        quantity: 'As needed',
        catalogNumber: 'D1306',
        manufacturer: 'Invitrogen',
        location: '-20°C Box 4',
        stockConcentration: '5 mg/mL',
      ),
      MaterialItem(
        id: 'm5',
        name: 'CD45 antibody',
        quantity: 'As needed',
        catalogNumber: '304012',
        manufacturer: 'BioLegend',
        location: 'Fridge door',
        stockConcentration: '0.2 mg/mL',
      ),
      MaterialItem(
        id: 'm6',
        name: 'SNA lectin',
        quantity: 'As needed',
        catalogNumber: 'B-1305-2',
        manufacturer: 'Vector Labs',
        location: 'Fridge door',
        stockConcentration: '2 mg/mL',
      ),
      MaterialItem(
        id: 'm7',
        name: 'MAL-II lectin',
        quantity: 'As needed',
        catalogNumber: 'B-1265-2',
        manufacturer: 'Vector Labs',
        location: 'Fridge door',
        stockConcentration: '2 mg/mL',
      ),
      MaterialItem(
        id: 'm8',
        name: 'Streptavidin-APC',
        quantity: 'As needed',
        catalogNumber: '405207',
        manufacturer: 'BioLegend',
        location: 'Fridge door',
        stockConcentration: '0.5 mg/mL',
      ),
    ],
    files: ['Assay Report'], // "Detection Table" and "Staining Table" removed as they are now formal Tables
    tables: [stainingTable, plateLayout, detectionTable, unassignedTable],
    steps: [
      ProtocolStep(
        id: 'step1',
        title: 'Prepare materials',
        instructions: 'Prepare the working area and reagents for the assay.',
        actionItems: [
          'Make FACS buffer',
          'Pre-warm reagents',
        ],
        materials: const [],
      ),
      ProtocolStep(
        id: 'step2',
        title: 'Detach cells',
        instructions: 'Detach THP1 cells gently before staining.',
        actionItems: [
          'Wash with PBS',
          'Add EDTA',
          'Incubate 2 min at 37 C',
          'Collect cells',
        ],
        materials: const [],
        actionTimers: {2: 10},
      ),
      ProtocolStep(
        id: 'step3',
        title: 'Count cells',
        instructions: 'Confirm cell number before continuing.',
        actionItems: [
          'Count using cell counter',
        ],
        materials: const [],
      ),
      ProtocolStep(
        id: 'step4',
        title: 'Wash cells',
        instructions: 'Clean the cells before lectin staining.',
        actionItems: [
          'Centrifuge',
          'Wash twice with buffer',
        ],
        materials: const [],
      ),
      ProtocolStep(
        id: 'step5',
        title: 'Lectin staining',
        instructions: 'Stain cells with the lectin panel on ice or at 4 C.',
        actionItems: [
          'Add SNA or MAL-II',
          'Incubate 1h at 4 C',
        ],
        materials: const [],
        actionTimers: {1: 3600},
        tableIds: ['table_staining_1', 'table_plate_1', 'table_detection_1'],
      ),
      ProtocolStep(
        id: 'step6',
        title: 'FACS acquisition',
        instructions: 'Prepare samples for final flow cytometry readout.',
        actionItems: [
          'Add DAPI',
          'Run cytometer',
        ],
        materials: const [],
      ),
    ],
  );

  final cellCultureProtocol = Protocol(
    id: 'cell_culture_1',
    title: 'THP-1 Cell Culture Maintenance',
    objective: 'Maintain THP-1 cells in exponential growth phase.',
    description: 'Regular feeding and passage of THP-1 suspension cells.',
    materials: [
      MaterialItem(id: 'm10', name: 'RPMI 1640', quantity: '500 mL', stockConcentration: '1X'),
      MaterialItem(id: 'm11', name: 'FBS', quantity: '50 mL', stockConcentration: '100%'),
      MaterialItem(id: 'm12', name: 'Pen/Strep', quantity: '5 mL', stockConcentration: '100X'),
    ],
    steps: [
      ProtocolStep(
        id: 'cc_step1',
        day: 0,
        title: 'Thaw Cells',
        instructions: 'Thaw one vial of THP-1 cells from liquid nitrogen.',
        actionItems: ['Warm media', 'Thaw vial', 'Centrifuge 5 min', 'Resuspend in 10mL'],
        actionTimers: {2: 300},
        materials: [],
      ),
      ProtocolStep(
        id: 'cc_step2',
        day: 1,
        title: 'Check Confluence',
        instructions: 'Check cell density and health.',
        actionItems: ['Observe under microscope', 'Count cells'],
        materials: [],
      ),
      ProtocolStep(
        id: 'cc_step3',
        day: 3,
        title: 'Passage Cells',
        instructions: 'Dilute cells to 2x10^5 cells/mL.',
        actionItems: ['Count cells', 'Calculate dilution', 'Add fresh media'],
        materials: [],
      ),
    ],
  );

  final templateProtocol = Protocol(
    id: 'template_1',
    title: 'Standard Flow Cytometry Template',
    objective: 'Template for general surface marker staining',
    description: 'Use this template to create specific flow cytometry protocols.',
    isTemplate: true,
    steps: [
      ProtocolStep(
        id: 'ts1',
        title: 'Block Cells',
        instructions: 'Incubate cells with Fc Block.',
        actionItems: ['Add block', 'Incubate 10 min'],
        materials: const [],
        actionTimers: {1: 600},
      ),
      ProtocolStep(
        id: 'ts2',
        title: 'Surface Staining',
        instructions: 'Add primary antibodies.',
        actionItems: ['Add antibodies', 'Incubate 30 min on ice'],
        materials: const [],
        actionTimers: {1: 1800},
      ),
    ],
  );

  final westernBlotTemplate = Protocol(
    id: 'template_2',
    title: 'Western Blot (Detailed Template)',
    objective: 'General template for protein separation and detection',
    description: 'A multi-day template including lysis, SDS-PAGE, transfer, and antibody incubation.',
    isTemplate: true,
    materials: [
      MaterialItem(id: 'wbm1', name: 'RIPA Lysis Buffer', quantity: '500 mL', stockConcentration: '1X'),
      MaterialItem(id: 'wbm2', name: 'Laemmli Buffer', quantity: '10 mL', stockConcentration: '4X'),
      MaterialItem(id: 'wbm3', name: 'Running Buffer', quantity: '1 L', stockConcentration: '10X'),
      MaterialItem(id: 'wbm4', name: 'Transfer Buffer', quantity: '1 L', stockConcentration: '10X'),
    ],
    steps: [
      ProtocolStep(
        id: 'wbs1',
        day: 1,
        phaseName: 'Sample Preparation',
        title: 'Cell Lysis',
        instructions: 'Lyse cells on ice and collect supernatant.',
        actionItems: ['Add RIPA', 'Scrape cells', 'Incubate 20 min', 'Centrifuge 15 min'],
        actionTimers: {2: 1200, 3: 900},
        materials: [],
      ),
      ProtocolStep(
        id: 'wbs2',
        day: 1,
        phaseName: 'Sample Preparation',
        title: 'Denaturation',
        instructions: 'Mix samples with 4X Laemmli and heat.',
        actionItems: ['Mix with 4X Laemmli', 'Heat at 95°C for 5 min'],
        actionTimers: {1: 300},
        materials: [],
      ),
      ProtocolStep(
        id: 'wbs3',
        day: 1,
        phaseName: 'SDS-PAGE & Transfer',
        title: 'Gel Running',
        instructions: 'Run SDS-PAGE at constant voltage.',
        actionItems: ['Load samples', 'Run 100V for 90 min'],
        actionTimers: {1: 5400},
        materials: [],
      ),
      ProtocolStep(
        id: 'wbs4',
        day: 1,
        phaseName: 'SDS-PAGE & Transfer',
        title: 'Transfer',
        instructions: 'Transfer proteins to PVDF/Nitrocellulose membrane.',
        actionItems: ['Activate PVDF', 'Assemble sandwich', 'Transfer 300mA for 1h'],
        actionTimers: {2: 3600},
        materials: [],
      ),
      ProtocolStep(
        id: 'wbs5',
        day: 1,
        phaseName: 'Antibody Incubation',
        title: 'Blocking',
        instructions: 'Block membrane in 5% milk or BSA.',
        actionItems: ['Incubate in blocking buffer 1h'],
        actionTimers: {0: 3600},
        materials: [],
      ),
      ProtocolStep(
        id: 'wbs6',
        day: 2,
        phaseName: 'Antibody Incubation',
        title: 'Primary Antibody',
        instructions: 'Incubate with primary antibody overnight at 4°C.',
        actionItems: ['Add primary antibody', 'Rock overnight'],
        materials: [],
      ),
    ],
  );

  return [thp1Protocol, cellCultureProtocol, templateProtocol, westernBlotTemplate];
}
