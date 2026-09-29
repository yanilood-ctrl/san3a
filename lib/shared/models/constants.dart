class AppConstants {
  static const List<Map<String, String>> mainCategories = [
    {'key': 'electrician', 'icon': '⚡'},
    {'key': 'carpenter',   'icon': '🔨'},
    {'key': 'plumber',     'icon': '🔧'},
    {'key': 'painter',     'icon': '🖌️'},
    {'key': 'mason',       'icon': '🧱'},
    {'key': 'gardener',    'icon': '🌿'},
  ];

  static const List<Map<String, String>> moreCategories = [
    {'key': 'ac_technician', 'icon': '❄️'},
    {'key': 'mechanic',      'icon': '🔧'},
    {'key': 'welder',        'icon': '🔥'},
    {'key': 'blacksmith',    'icon': '⚒️'},
    {'key': 'tailor',        'icon': '🧵'},
    {'key': 'cleaner',       'icon': '🧹'},
    {'key': 'other_services', 'icon': '✨'},
  ];

  static List<Map<String, String>> get allCategories => [...mainCategories, ...moreCategories];
}
