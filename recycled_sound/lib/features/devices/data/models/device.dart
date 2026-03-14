/// 26-field device model matching the Recycled Sound device register.
class Device {
  const Device({
    required this.id,
    required this.brand,
    required this.model,
    this.type = '',
    this.year = '',
    this.serialLeft = '',
    this.serialRight = '',
    this.batterySize = '',
    this.domeType = '',
    this.waxFilter = '',
    this.receiver = '',
    this.programmingInterface = '',
    this.techLevel = '',
    this.gainRange = '',
    this.fittingRange = '',
    this.remoteFT = false,
    this.appCompatible = false,
    this.auracast = false,
    this.chargerType = '',
    this.accessories = const [],
    this.condition = '',
    this.qaStatus = 'pending_qa',
    this.status = 'donated',
    this.servicingNotes = '',
    this.servicingCost = 0,
    this.donorId = '',
    this.scanId = '',
    this.photos = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String brand;
  final String model;
  final String type;
  final String year;
  final String serialLeft;
  final String serialRight;
  final String batterySize;
  final String domeType;
  final String waxFilter;
  final String receiver;
  final String programmingInterface;
  final String techLevel;
  final String gainRange;
  final String fittingRange;
  final bool remoteFT;
  final bool appCompatible;
  final bool auracast;
  final String chargerType;
  final List<String> accessories;
  final String condition;
  final String qaStatus;
  final String status;
  final String servicingNotes;
  final double servicingCost;
  final String donorId;
  final String scanId;
  final List<String> photos;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Sample devices from the existing register for MVP display.
  static List<Device> mockDevices() => [
        const Device(
          id: '1',
          brand: 'Phonak',
          model: 'Audéo P90',
          type: 'RIC',
          year: '2021',
          batterySize: '312',
          qaStatus: 'passed',
          status: 'ready',
        ),
        const Device(
          id: '2',
          brand: 'Oticon',
          model: 'More 1',
          type: 'BTE',
          year: '2022',
          batterySize: '13',
          qaStatus: 'pending_qa',
          status: 'donated',
        ),
        const Device(
          id: '3',
          brand: 'Signia',
          model: 'Pure 7Nx',
          type: 'RIC',
          year: '2020',
          batterySize: '312',
          qaStatus: 'passed',
          status: 'matched',
        ),
        const Device(
          id: '4',
          brand: 'GN Resound',
          model: 'ONE 9',
          type: 'RIC',
          year: '2023',
          batterySize: 'Rechargeable',
          qaStatus: 'pending_qa',
          status: 'donated',
        ),
        const Device(
          id: '5',
          brand: 'Widex',
          model: 'Moment 440',
          type: 'RIC',
          year: '2021',
          batterySize: '10',
          qaStatus: 'failed',
          status: 'servicing',
        ),
      ];
}
