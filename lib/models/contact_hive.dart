import 'package:hive/hive.dart';

part 'contact_hive.g.dart';

@HiveType(typeId: 3)
class ContactHive extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String name;
  @HiveField(2)
  String phone;

  ContactHive({required this.id, required this.name, required this.phone});
}
