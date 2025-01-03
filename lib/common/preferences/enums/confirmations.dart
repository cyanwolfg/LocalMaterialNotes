import '../../constants/constants.dart';
import '../../extensions/iterable_extension.dart';
import '../preference_key.dart';

/// Lists the options for the confirmations asked for user actions such as pining and deleting notes.
enum Confirmations {
  /// Never ask for a confirmation.
  none,

  /// Asks confirmations only for irreversible actions.
  irreversible,

  /// Always ask for a confirmation.
  all,
  ;

  /// The value of the preference if set, or its default value otherwise.
  factory Confirmations.fromPreference() {
    final confirmations = Confirmations.values.byNameOrNull(
      PreferenceKey.confirmations.getPreference(),
    );

    // Reset the malformed preference to its default value
    if (confirmations == null) {
      PreferenceKey.confirmations.reset();

      return Confirmations.values.byName(PreferenceKey.confirmations.defaultValue);
    }

    return confirmations;
  }

  /// Returns the title of the preference for the settings page.
  String get title {
    switch (this) {
      case none:
        return l.settings_confirmations_title_none;
      case irreversible:
        return l.settings_confirmations_title_irreversible;
      case all:
        return l.settings_confirmations_title_all;
    }
  }
}
