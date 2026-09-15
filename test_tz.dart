import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  tz.initializeTimeZones();
  try {
    tz.setLocalLocation(tz.getLocation('UTC'));
    print('Success');
  } catch (e) {
    print('Error: $e');
  }
}
