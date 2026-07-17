final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

enum PlatformPayloadFailureReason { missingField, wrongType, invalidValue }

class PlatformPayloadException implements Exception {
  const PlatformPayloadException({required this.field, required this.reason});

  final String field;
  final PlatformPayloadFailureReason reason;

  @override
  String toString() {
    return 'PlatformPayloadException(field: $field, reason: ${reason.name})';
  }
}

class PlatformPayloadReader {
  const PlatformPayloadReader(this._payload);

  final Map<String, Object?> _payload;

  String requiredString(String field) {
    final value = _requiredValue(field);
    if (value is! String) {
      throw _wrongType(field);
    }
    if (value.trim().isEmpty) {
      throw _invalidValue(field);
    }
    return value;
  }

  String? optionalString(String field) {
    if (!_payload.containsKey(field) || _payload[field] == null) {
      return null;
    }
    final value = _payload[field];
    if (value is! String) {
      throw _wrongType(field);
    }
    if (value.trim().isEmpty) {
      throw _invalidValue(field);
    }
    return value;
  }

  int requiredInt(String field) {
    final value = _requiredValue(field);
    if (value is! int) {
      throw _wrongType(field);
    }
    return value;
  }

  int? optionalInt(String field) {
    if (!_payload.containsKey(field) || _payload[field] == null) {
      return null;
    }
    final value = _payload[field];
    if (value is! int) {
      throw _wrongType(field);
    }
    return value;
  }

  bool requiredBool(String field) {
    final value = _requiredValue(field);
    if (value is! bool) {
      throw _wrongType(field);
    }
    return value;
  }

  bool? optionalBool(String field) {
    if (!_payload.containsKey(field) || _payload[field] == null) {
      return null;
    }
    final value = _payload[field];
    if (value is! bool) {
      throw _wrongType(field);
    }
    return value;
  }

  DateTime requiredDateTime(String field) {
    return _readDateTime(field, _requiredValue(field));
  }

  DateTime? optionalDateTime(String field) {
    if (!_payload.containsKey(field) || _payload[field] == null) {
      return null;
    }
    return _readDateTime(field, _payload[field]);
  }

  String requiredUuid(String field) {
    final value = requiredString(field);
    if (!_uuidPattern.hasMatch(value)) {
      throw _invalidValue(field);
    }
    return value.toLowerCase();
  }

  Map<String, Object?> requiredMap(String field) {
    final value = _requiredValue(field);
    if (value is! Map) {
      throw _wrongType(field);
    }

    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw _wrongType(field);
      }
      result[key] = entry.value;
    }
    return Map<String, Object?>.unmodifiable(result);
  }

  Object _requiredValue(String field) {
    if (!_payload.containsKey(field) || _payload[field] == null) {
      throw PlatformPayloadException(
        field: field,
        reason: PlatformPayloadFailureReason.missingField,
      );
    }
    return _payload[field]!;
  }

  DateTime _readDateTime(String field, Object? value) {
    final DateTime? parsed;
    if (value is DateTime) {
      parsed = value;
    } else if (value is String) {
      parsed = DateTime.tryParse(value);
    } else {
      throw _wrongType(field);
    }

    if (parsed == null) {
      throw _invalidValue(field);
    }
    return parsed.toUtc();
  }
}

PlatformPayloadException _wrongType(String field) {
  return PlatformPayloadException(
    field: field,
    reason: PlatformPayloadFailureReason.wrongType,
  );
}

PlatformPayloadException _invalidValue(String field) {
  return PlatformPayloadException(
    field: field,
    reason: PlatformPayloadFailureReason.invalidValue,
  );
}
