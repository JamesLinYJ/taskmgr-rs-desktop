// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'api.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BridgeActionRequest {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeActionRequest);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'BridgeActionRequest()';
}


}

/// @nodoc
class $BridgeActionRequestCopyWith<$Res>  {
$BridgeActionRequestCopyWith(BridgeActionRequest _, $Res Function(BridgeActionRequest) __);
}


/// Adds pattern-matching-related methods to [BridgeActionRequest].
extension BridgeActionRequestPatterns on BridgeActionRequest {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( BridgeActionRequest_RunTask value)?  runTask,TResult Function( BridgeActionRequest_EndProcess value)?  endProcess,TResult Function( BridgeActionRequest_SetPriority value)?  setPriority,TResult Function( BridgeActionRequest_SetNice value)?  setNice,TResult Function( BridgeActionRequest_SetAffinity value)?  setAffinity,TResult Function( BridgeActionRequest_OpenFileLocation value)?  openFileLocation,TResult Function( BridgeActionRequest_Window value)?  window,TResult Function( BridgeActionRequest_ArrangeWindows value)?  arrangeWindows,TResult Function( BridgeActionRequest_UserSession value)?  userSession,required TResult orElse(),}){
final _that = this;
switch (_that) {
case BridgeActionRequest_RunTask() when runTask != null:
return runTask(_that);case BridgeActionRequest_EndProcess() when endProcess != null:
return endProcess(_that);case BridgeActionRequest_SetPriority() when setPriority != null:
return setPriority(_that);case BridgeActionRequest_SetNice() when setNice != null:
return setNice(_that);case BridgeActionRequest_SetAffinity() when setAffinity != null:
return setAffinity(_that);case BridgeActionRequest_OpenFileLocation() when openFileLocation != null:
return openFileLocation(_that);case BridgeActionRequest_Window() when window != null:
return window(_that);case BridgeActionRequest_ArrangeWindows() when arrangeWindows != null:
return arrangeWindows(_that);case BridgeActionRequest_UserSession() when userSession != null:
return userSession(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( BridgeActionRequest_RunTask value)  runTask,required TResult Function( BridgeActionRequest_EndProcess value)  endProcess,required TResult Function( BridgeActionRequest_SetPriority value)  setPriority,required TResult Function( BridgeActionRequest_SetNice value)  setNice,required TResult Function( BridgeActionRequest_SetAffinity value)  setAffinity,required TResult Function( BridgeActionRequest_OpenFileLocation value)  openFileLocation,required TResult Function( BridgeActionRequest_Window value)  window,required TResult Function( BridgeActionRequest_ArrangeWindows value)  arrangeWindows,required TResult Function( BridgeActionRequest_UserSession value)  userSession,}){
final _that = this;
switch (_that) {
case BridgeActionRequest_RunTask():
return runTask(_that);case BridgeActionRequest_EndProcess():
return endProcess(_that);case BridgeActionRequest_SetPriority():
return setPriority(_that);case BridgeActionRequest_SetNice():
return setNice(_that);case BridgeActionRequest_SetAffinity():
return setAffinity(_that);case BridgeActionRequest_OpenFileLocation():
return openFileLocation(_that);case BridgeActionRequest_Window():
return window(_that);case BridgeActionRequest_ArrangeWindows():
return arrangeWindows(_that);case BridgeActionRequest_UserSession():
return userSession(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( BridgeActionRequest_RunTask value)?  runTask,TResult? Function( BridgeActionRequest_EndProcess value)?  endProcess,TResult? Function( BridgeActionRequest_SetPriority value)?  setPriority,TResult? Function( BridgeActionRequest_SetNice value)?  setNice,TResult? Function( BridgeActionRequest_SetAffinity value)?  setAffinity,TResult? Function( BridgeActionRequest_OpenFileLocation value)?  openFileLocation,TResult? Function( BridgeActionRequest_Window value)?  window,TResult? Function( BridgeActionRequest_ArrangeWindows value)?  arrangeWindows,TResult? Function( BridgeActionRequest_UserSession value)?  userSession,}){
final _that = this;
switch (_that) {
case BridgeActionRequest_RunTask() when runTask != null:
return runTask(_that);case BridgeActionRequest_EndProcess() when endProcess != null:
return endProcess(_that);case BridgeActionRequest_SetPriority() when setPriority != null:
return setPriority(_that);case BridgeActionRequest_SetNice() when setNice != null:
return setNice(_that);case BridgeActionRequest_SetAffinity() when setAffinity != null:
return setAffinity(_that);case BridgeActionRequest_OpenFileLocation() when openFileLocation != null:
return openFileLocation(_that);case BridgeActionRequest_Window() when window != null:
return window(_that);case BridgeActionRequest_ArrangeWindows() when arrangeWindows != null:
return arrangeWindows(_that);case BridgeActionRequest_UserSession() when userSession != null:
return userSession(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String commandLine)?  runTask,TResult Function( ProcessIdentity identity,  bool includeDescendants)?  endProcess,TResult Function( ProcessIdentity identity,  ProcessPriority priority)?  setPriority,TResult Function( ProcessIdentity identity,  int nice)?  setNice,TResult Function( ProcessIdentity identity,  Uint32List logicalProcessors)?  setAffinity,TResult Function( ProcessIdentity identity)?  openFileLocation,TResult Function( ApplicationIdentity identity,  WindowAction operation)?  window,TResult Function( List<ApplicationIdentity> identities,  WindowArrangement arrangement)?  arrangeWindows,TResult Function( UserSessionIdentity identity,  UserAction operation,  String? title,  String? message)?  userSession,required TResult orElse(),}) {final _that = this;
switch (_that) {
case BridgeActionRequest_RunTask() when runTask != null:
return runTask(_that.commandLine);case BridgeActionRequest_EndProcess() when endProcess != null:
return endProcess(_that.identity,_that.includeDescendants);case BridgeActionRequest_SetPriority() when setPriority != null:
return setPriority(_that.identity,_that.priority);case BridgeActionRequest_SetNice() when setNice != null:
return setNice(_that.identity,_that.nice);case BridgeActionRequest_SetAffinity() when setAffinity != null:
return setAffinity(_that.identity,_that.logicalProcessors);case BridgeActionRequest_OpenFileLocation() when openFileLocation != null:
return openFileLocation(_that.identity);case BridgeActionRequest_Window() when window != null:
return window(_that.identity,_that.operation);case BridgeActionRequest_ArrangeWindows() when arrangeWindows != null:
return arrangeWindows(_that.identities,_that.arrangement);case BridgeActionRequest_UserSession() when userSession != null:
return userSession(_that.identity,_that.operation,_that.title,_that.message);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String commandLine)  runTask,required TResult Function( ProcessIdentity identity,  bool includeDescendants)  endProcess,required TResult Function( ProcessIdentity identity,  ProcessPriority priority)  setPriority,required TResult Function( ProcessIdentity identity,  int nice)  setNice,required TResult Function( ProcessIdentity identity,  Uint32List logicalProcessors)  setAffinity,required TResult Function( ProcessIdentity identity)  openFileLocation,required TResult Function( ApplicationIdentity identity,  WindowAction operation)  window,required TResult Function( List<ApplicationIdentity> identities,  WindowArrangement arrangement)  arrangeWindows,required TResult Function( UserSessionIdentity identity,  UserAction operation,  String? title,  String? message)  userSession,}) {final _that = this;
switch (_that) {
case BridgeActionRequest_RunTask():
return runTask(_that.commandLine);case BridgeActionRequest_EndProcess():
return endProcess(_that.identity,_that.includeDescendants);case BridgeActionRequest_SetPriority():
return setPriority(_that.identity,_that.priority);case BridgeActionRequest_SetNice():
return setNice(_that.identity,_that.nice);case BridgeActionRequest_SetAffinity():
return setAffinity(_that.identity,_that.logicalProcessors);case BridgeActionRequest_OpenFileLocation():
return openFileLocation(_that.identity);case BridgeActionRequest_Window():
return window(_that.identity,_that.operation);case BridgeActionRequest_ArrangeWindows():
return arrangeWindows(_that.identities,_that.arrangement);case BridgeActionRequest_UserSession():
return userSession(_that.identity,_that.operation,_that.title,_that.message);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String commandLine)?  runTask,TResult? Function( ProcessIdentity identity,  bool includeDescendants)?  endProcess,TResult? Function( ProcessIdentity identity,  ProcessPriority priority)?  setPriority,TResult? Function( ProcessIdentity identity,  int nice)?  setNice,TResult? Function( ProcessIdentity identity,  Uint32List logicalProcessors)?  setAffinity,TResult? Function( ProcessIdentity identity)?  openFileLocation,TResult? Function( ApplicationIdentity identity,  WindowAction operation)?  window,TResult? Function( List<ApplicationIdentity> identities,  WindowArrangement arrangement)?  arrangeWindows,TResult? Function( UserSessionIdentity identity,  UserAction operation,  String? title,  String? message)?  userSession,}) {final _that = this;
switch (_that) {
case BridgeActionRequest_RunTask() when runTask != null:
return runTask(_that.commandLine);case BridgeActionRequest_EndProcess() when endProcess != null:
return endProcess(_that.identity,_that.includeDescendants);case BridgeActionRequest_SetPriority() when setPriority != null:
return setPriority(_that.identity,_that.priority);case BridgeActionRequest_SetNice() when setNice != null:
return setNice(_that.identity,_that.nice);case BridgeActionRequest_SetAffinity() when setAffinity != null:
return setAffinity(_that.identity,_that.logicalProcessors);case BridgeActionRequest_OpenFileLocation() when openFileLocation != null:
return openFileLocation(_that.identity);case BridgeActionRequest_Window() when window != null:
return window(_that.identity,_that.operation);case BridgeActionRequest_ArrangeWindows() when arrangeWindows != null:
return arrangeWindows(_that.identities,_that.arrangement);case BridgeActionRequest_UserSession() when userSession != null:
return userSession(_that.identity,_that.operation,_that.title,_that.message);case _:
  return null;

}
}

}

/// @nodoc


class BridgeActionRequest_RunTask extends BridgeActionRequest {
  const BridgeActionRequest_RunTask({required this.commandLine}): super._();


 final  String commandLine;

/// Create a copy of BridgeActionRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BridgeActionRequest_RunTaskCopyWith<BridgeActionRequest_RunTask> get copyWith => _$BridgeActionRequest_RunTaskCopyWithImpl<BridgeActionRequest_RunTask>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeActionRequest_RunTask&&(identical(other.commandLine, commandLine) || other.commandLine == commandLine));
}


@override
int get hashCode => Object.hash(runtimeType,commandLine);

@override
String toString() {
  return 'BridgeActionRequest.runTask(commandLine: $commandLine)';
}


}

/// @nodoc
abstract mixin class $BridgeActionRequest_RunTaskCopyWith<$Res> implements $BridgeActionRequestCopyWith<$Res> {
  factory $BridgeActionRequest_RunTaskCopyWith(BridgeActionRequest_RunTask value, $Res Function(BridgeActionRequest_RunTask) _then) = _$BridgeActionRequest_RunTaskCopyWithImpl;
@useResult
$Res call({
 String commandLine
});




}
/// @nodoc
class _$BridgeActionRequest_RunTaskCopyWithImpl<$Res>
    implements $BridgeActionRequest_RunTaskCopyWith<$Res> {
  _$BridgeActionRequest_RunTaskCopyWithImpl(this._self, this._then);

  final BridgeActionRequest_RunTask _self;
  final $Res Function(BridgeActionRequest_RunTask) _then;

/// Create a copy of BridgeActionRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? commandLine = null,}) {
  return _then(BridgeActionRequest_RunTask(
commandLine: null == commandLine ? _self.commandLine : commandLine // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class BridgeActionRequest_EndProcess extends BridgeActionRequest {
  const BridgeActionRequest_EndProcess({required this.identity, required this.includeDescendants}): super._();


 final  ProcessIdentity identity;
 final  bool includeDescendants;

/// Create a copy of BridgeActionRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BridgeActionRequest_EndProcessCopyWith<BridgeActionRequest_EndProcess> get copyWith => _$BridgeActionRequest_EndProcessCopyWithImpl<BridgeActionRequest_EndProcess>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeActionRequest_EndProcess&&(identical(other.identity, identity) || other.identity == identity)&&(identical(other.includeDescendants, includeDescendants) || other.includeDescendants == includeDescendants));
}


@override
int get hashCode => Object.hash(runtimeType,identity,includeDescendants);

@override
String toString() {
  return 'BridgeActionRequest.endProcess(identity: $identity, includeDescendants: $includeDescendants)';
}


}

/// @nodoc
abstract mixin class $BridgeActionRequest_EndProcessCopyWith<$Res> implements $BridgeActionRequestCopyWith<$Res> {
  factory $BridgeActionRequest_EndProcessCopyWith(BridgeActionRequest_EndProcess value, $Res Function(BridgeActionRequest_EndProcess) _then) = _$BridgeActionRequest_EndProcessCopyWithImpl;
@useResult
$Res call({
 ProcessIdentity identity, bool includeDescendants
});




}
/// @nodoc
class _$BridgeActionRequest_EndProcessCopyWithImpl<$Res>
    implements $BridgeActionRequest_EndProcessCopyWith<$Res> {
  _$BridgeActionRequest_EndProcessCopyWithImpl(this._self, this._then);

  final BridgeActionRequest_EndProcess _self;
  final $Res Function(BridgeActionRequest_EndProcess) _then;

/// Create a copy of BridgeActionRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? identity = null,Object? includeDescendants = null,}) {
  return _then(BridgeActionRequest_EndProcess(
identity: null == identity ? _self.identity : identity // ignore: cast_nullable_to_non_nullable
as ProcessIdentity,includeDescendants: null == includeDescendants ? _self.includeDescendants : includeDescendants // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class BridgeActionRequest_SetPriority extends BridgeActionRequest {
  const BridgeActionRequest_SetPriority({required this.identity, required this.priority}): super._();


 final  ProcessIdentity identity;
 final  ProcessPriority priority;

/// Create a copy of BridgeActionRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BridgeActionRequest_SetPriorityCopyWith<BridgeActionRequest_SetPriority> get copyWith => _$BridgeActionRequest_SetPriorityCopyWithImpl<BridgeActionRequest_SetPriority>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeActionRequest_SetPriority&&(identical(other.identity, identity) || other.identity == identity)&&(identical(other.priority, priority) || other.priority == priority));
}


@override
int get hashCode => Object.hash(runtimeType,identity,priority);

@override
String toString() {
  return 'BridgeActionRequest.setPriority(identity: $identity, priority: $priority)';
}


}

/// @nodoc
abstract mixin class $BridgeActionRequest_SetPriorityCopyWith<$Res> implements $BridgeActionRequestCopyWith<$Res> {
  factory $BridgeActionRequest_SetPriorityCopyWith(BridgeActionRequest_SetPriority value, $Res Function(BridgeActionRequest_SetPriority) _then) = _$BridgeActionRequest_SetPriorityCopyWithImpl;
@useResult
$Res call({
 ProcessIdentity identity, ProcessPriority priority
});




}
/// @nodoc
class _$BridgeActionRequest_SetPriorityCopyWithImpl<$Res>
    implements $BridgeActionRequest_SetPriorityCopyWith<$Res> {
  _$BridgeActionRequest_SetPriorityCopyWithImpl(this._self, this._then);

  final BridgeActionRequest_SetPriority _self;
  final $Res Function(BridgeActionRequest_SetPriority) _then;

/// Create a copy of BridgeActionRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? identity = null,Object? priority = null,}) {
  return _then(BridgeActionRequest_SetPriority(
identity: null == identity ? _self.identity : identity // ignore: cast_nullable_to_non_nullable
as ProcessIdentity,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as ProcessPriority,
  ));
}


}

/// @nodoc


class BridgeActionRequest_SetNice extends BridgeActionRequest {
  const BridgeActionRequest_SetNice({required this.identity, required this.nice}): super._();


 final  ProcessIdentity identity;
 final  int nice;

/// Create a copy of BridgeActionRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BridgeActionRequest_SetNiceCopyWith<BridgeActionRequest_SetNice> get copyWith => _$BridgeActionRequest_SetNiceCopyWithImpl<BridgeActionRequest_SetNice>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeActionRequest_SetNice&&(identical(other.identity, identity) || other.identity == identity)&&(identical(other.nice, nice) || other.nice == nice));
}


@override
int get hashCode => Object.hash(runtimeType,identity,nice);

@override
String toString() {
  return 'BridgeActionRequest.setNice(identity: $identity, nice: $nice)';
}


}

/// @nodoc
abstract mixin class $BridgeActionRequest_SetNiceCopyWith<$Res> implements $BridgeActionRequestCopyWith<$Res> {
  factory $BridgeActionRequest_SetNiceCopyWith(BridgeActionRequest_SetNice value, $Res Function(BridgeActionRequest_SetNice) _then) = _$BridgeActionRequest_SetNiceCopyWithImpl;
@useResult
$Res call({
 ProcessIdentity identity, int nice
});




}
/// @nodoc
class _$BridgeActionRequest_SetNiceCopyWithImpl<$Res>
    implements $BridgeActionRequest_SetNiceCopyWith<$Res> {
  _$BridgeActionRequest_SetNiceCopyWithImpl(this._self, this._then);

  final BridgeActionRequest_SetNice _self;
  final $Res Function(BridgeActionRequest_SetNice) _then;

/// Create a copy of BridgeActionRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? identity = null,Object? nice = null,}) {
  return _then(BridgeActionRequest_SetNice(
identity: null == identity ? _self.identity : identity // ignore: cast_nullable_to_non_nullable
as ProcessIdentity,nice: null == nice ? _self.nice : nice // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class BridgeActionRequest_SetAffinity extends BridgeActionRequest {
  const BridgeActionRequest_SetAffinity({required this.identity, required this.logicalProcessors}): super._();


 final  ProcessIdentity identity;
 final  Uint32List logicalProcessors;

/// Create a copy of BridgeActionRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BridgeActionRequest_SetAffinityCopyWith<BridgeActionRequest_SetAffinity> get copyWith => _$BridgeActionRequest_SetAffinityCopyWithImpl<BridgeActionRequest_SetAffinity>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeActionRequest_SetAffinity&&(identical(other.identity, identity) || other.identity == identity)&&const DeepCollectionEquality().equals(other.logicalProcessors, logicalProcessors));
}


@override
int get hashCode => Object.hash(runtimeType,identity,const DeepCollectionEquality().hash(logicalProcessors));

@override
String toString() {
  return 'BridgeActionRequest.setAffinity(identity: $identity, logicalProcessors: $logicalProcessors)';
}


}

/// @nodoc
abstract mixin class $BridgeActionRequest_SetAffinityCopyWith<$Res> implements $BridgeActionRequestCopyWith<$Res> {
  factory $BridgeActionRequest_SetAffinityCopyWith(BridgeActionRequest_SetAffinity value, $Res Function(BridgeActionRequest_SetAffinity) _then) = _$BridgeActionRequest_SetAffinityCopyWithImpl;
@useResult
$Res call({
 ProcessIdentity identity, Uint32List logicalProcessors
});




}
/// @nodoc
class _$BridgeActionRequest_SetAffinityCopyWithImpl<$Res>
    implements $BridgeActionRequest_SetAffinityCopyWith<$Res> {
  _$BridgeActionRequest_SetAffinityCopyWithImpl(this._self, this._then);

  final BridgeActionRequest_SetAffinity _self;
  final $Res Function(BridgeActionRequest_SetAffinity) _then;

/// Create a copy of BridgeActionRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? identity = null,Object? logicalProcessors = null,}) {
  return _then(BridgeActionRequest_SetAffinity(
identity: null == identity ? _self.identity : identity // ignore: cast_nullable_to_non_nullable
as ProcessIdentity,logicalProcessors: null == logicalProcessors ? _self.logicalProcessors : logicalProcessors // ignore: cast_nullable_to_non_nullable
as Uint32List,
  ));
}


}

/// @nodoc


class BridgeActionRequest_OpenFileLocation extends BridgeActionRequest {
  const BridgeActionRequest_OpenFileLocation({required this.identity}): super._();


 final  ProcessIdentity identity;

/// Create a copy of BridgeActionRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BridgeActionRequest_OpenFileLocationCopyWith<BridgeActionRequest_OpenFileLocation> get copyWith => _$BridgeActionRequest_OpenFileLocationCopyWithImpl<BridgeActionRequest_OpenFileLocation>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeActionRequest_OpenFileLocation&&(identical(other.identity, identity) || other.identity == identity));
}


@override
int get hashCode => Object.hash(runtimeType,identity);

@override
String toString() {
  return 'BridgeActionRequest.openFileLocation(identity: $identity)';
}


}

/// @nodoc
abstract mixin class $BridgeActionRequest_OpenFileLocationCopyWith<$Res> implements $BridgeActionRequestCopyWith<$Res> {
  factory $BridgeActionRequest_OpenFileLocationCopyWith(BridgeActionRequest_OpenFileLocation value, $Res Function(BridgeActionRequest_OpenFileLocation) _then) = _$BridgeActionRequest_OpenFileLocationCopyWithImpl;
@useResult
$Res call({
 ProcessIdentity identity
});




}
/// @nodoc
class _$BridgeActionRequest_OpenFileLocationCopyWithImpl<$Res>
    implements $BridgeActionRequest_OpenFileLocationCopyWith<$Res> {
  _$BridgeActionRequest_OpenFileLocationCopyWithImpl(this._self, this._then);

  final BridgeActionRequest_OpenFileLocation _self;
  final $Res Function(BridgeActionRequest_OpenFileLocation) _then;

/// Create a copy of BridgeActionRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? identity = null,}) {
  return _then(BridgeActionRequest_OpenFileLocation(
identity: null == identity ? _self.identity : identity // ignore: cast_nullable_to_non_nullable
as ProcessIdentity,
  ));
}


}

/// @nodoc


class BridgeActionRequest_Window extends BridgeActionRequest {
  const BridgeActionRequest_Window({required this.identity, required this.operation}): super._();


 final  ApplicationIdentity identity;
 final  WindowAction operation;

/// Create a copy of BridgeActionRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BridgeActionRequest_WindowCopyWith<BridgeActionRequest_Window> get copyWith => _$BridgeActionRequest_WindowCopyWithImpl<BridgeActionRequest_Window>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeActionRequest_Window&&(identical(other.identity, identity) || other.identity == identity)&&(identical(other.operation, operation) || other.operation == operation));
}


@override
int get hashCode => Object.hash(runtimeType,identity,operation);

@override
String toString() {
  return 'BridgeActionRequest.window(identity: $identity, operation: $operation)';
}


}

/// @nodoc
abstract mixin class $BridgeActionRequest_WindowCopyWith<$Res> implements $BridgeActionRequestCopyWith<$Res> {
  factory $BridgeActionRequest_WindowCopyWith(BridgeActionRequest_Window value, $Res Function(BridgeActionRequest_Window) _then) = _$BridgeActionRequest_WindowCopyWithImpl;
@useResult
$Res call({
 ApplicationIdentity identity, WindowAction operation
});




}
/// @nodoc
class _$BridgeActionRequest_WindowCopyWithImpl<$Res>
    implements $BridgeActionRequest_WindowCopyWith<$Res> {
  _$BridgeActionRequest_WindowCopyWithImpl(this._self, this._then);

  final BridgeActionRequest_Window _self;
  final $Res Function(BridgeActionRequest_Window) _then;

/// Create a copy of BridgeActionRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? identity = null,Object? operation = null,}) {
  return _then(BridgeActionRequest_Window(
identity: null == identity ? _self.identity : identity // ignore: cast_nullable_to_non_nullable
as ApplicationIdentity,operation: null == operation ? _self.operation : operation // ignore: cast_nullable_to_non_nullable
as WindowAction,
  ));
}


}

/// @nodoc


class BridgeActionRequest_ArrangeWindows extends BridgeActionRequest {
  const BridgeActionRequest_ArrangeWindows({required final  List<ApplicationIdentity> identities, required this.arrangement}): _identities = identities,super._();


 final  List<ApplicationIdentity> _identities;
 List<ApplicationIdentity> get identities {
  if (_identities is EqualUnmodifiableListView) return _identities;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_identities);
}

 final  WindowArrangement arrangement;

/// Create a copy of BridgeActionRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BridgeActionRequest_ArrangeWindowsCopyWith<BridgeActionRequest_ArrangeWindows> get copyWith => _$BridgeActionRequest_ArrangeWindowsCopyWithImpl<BridgeActionRequest_ArrangeWindows>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeActionRequest_ArrangeWindows&&const DeepCollectionEquality().equals(other._identities, _identities)&&(identical(other.arrangement, arrangement) || other.arrangement == arrangement));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_identities),arrangement);

@override
String toString() {
  return 'BridgeActionRequest.arrangeWindows(identities: $identities, arrangement: $arrangement)';
}


}

/// @nodoc
abstract mixin class $BridgeActionRequest_ArrangeWindowsCopyWith<$Res> implements $BridgeActionRequestCopyWith<$Res> {
  factory $BridgeActionRequest_ArrangeWindowsCopyWith(BridgeActionRequest_ArrangeWindows value, $Res Function(BridgeActionRequest_ArrangeWindows) _then) = _$BridgeActionRequest_ArrangeWindowsCopyWithImpl;
@useResult
$Res call({
 List<ApplicationIdentity> identities, WindowArrangement arrangement
});




}
/// @nodoc
class _$BridgeActionRequest_ArrangeWindowsCopyWithImpl<$Res>
    implements $BridgeActionRequest_ArrangeWindowsCopyWith<$Res> {
  _$BridgeActionRequest_ArrangeWindowsCopyWithImpl(this._self, this._then);

  final BridgeActionRequest_ArrangeWindows _self;
  final $Res Function(BridgeActionRequest_ArrangeWindows) _then;

/// Create a copy of BridgeActionRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? identities = null,Object? arrangement = null,}) {
  return _then(BridgeActionRequest_ArrangeWindows(
identities: null == identities ? _self._identities : identities // ignore: cast_nullable_to_non_nullable
as List<ApplicationIdentity>,arrangement: null == arrangement ? _self.arrangement : arrangement // ignore: cast_nullable_to_non_nullable
as WindowArrangement,
  ));
}


}

/// @nodoc


class BridgeActionRequest_UserSession extends BridgeActionRequest {
  const BridgeActionRequest_UserSession({required this.identity, required this.operation, this.title, this.message}): super._();


 final  UserSessionIdentity identity;
 final  UserAction operation;
 final  String? title;
 final  String? message;

/// Create a copy of BridgeActionRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BridgeActionRequest_UserSessionCopyWith<BridgeActionRequest_UserSession> get copyWith => _$BridgeActionRequest_UserSessionCopyWithImpl<BridgeActionRequest_UserSession>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeActionRequest_UserSession&&(identical(other.identity, identity) || other.identity == identity)&&(identical(other.operation, operation) || other.operation == operation)&&(identical(other.title, title) || other.title == title)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,identity,operation,title,message);

@override
String toString() {
  return 'BridgeActionRequest.userSession(identity: $identity, operation: $operation, title: $title, message: $message)';
}


}

/// @nodoc
abstract mixin class $BridgeActionRequest_UserSessionCopyWith<$Res> implements $BridgeActionRequestCopyWith<$Res> {
  factory $BridgeActionRequest_UserSessionCopyWith(BridgeActionRequest_UserSession value, $Res Function(BridgeActionRequest_UserSession) _then) = _$BridgeActionRequest_UserSessionCopyWithImpl;
@useResult
$Res call({
 UserSessionIdentity identity, UserAction operation, String? title, String? message
});




}
/// @nodoc
class _$BridgeActionRequest_UserSessionCopyWithImpl<$Res>
    implements $BridgeActionRequest_UserSessionCopyWith<$Res> {
  _$BridgeActionRequest_UserSessionCopyWithImpl(this._self, this._then);

  final BridgeActionRequest_UserSession _self;
  final $Res Function(BridgeActionRequest_UserSession) _then;

/// Create a copy of BridgeActionRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? identity = null,Object? operation = null,Object? title = freezed,Object? message = freezed,}) {
  return _then(BridgeActionRequest_UserSession(
identity: null == identity ? _self.identity : identity // ignore: cast_nullable_to_non_nullable
as UserSessionIdentity,operation: null == operation ? _self.operation : operation // ignore: cast_nullable_to_non_nullable
as UserAction,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$BridgeBackendEvent {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeBackendEvent);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'BridgeBackendEvent()';
}


}

/// @nodoc
class $BridgeBackendEventCopyWith<$Res>  {
$BridgeBackendEventCopyWith(BridgeBackendEvent _, $Res Function(BridgeBackendEvent) __);
}


/// Adds pattern-matching-related methods to [BridgeBackendEvent].
extension BridgeBackendEventPatterns on BridgeBackendEvent {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( BridgeBackendEvent_Capabilities value)?  capabilities,TResult Function( BridgeBackendEvent_Applications value)?  applications,TResult Function( BridgeBackendEvent_Processes value)?  processes,TResult Function( BridgeBackendEvent_Performance value)?  performance,TResult Function( BridgeBackendEvent_Cpu value)?  cpu,TResult Function( BridgeBackendEvent_Gpu value)?  gpu,TResult Function( BridgeBackendEvent_Network value)?  network,TResult Function( BridgeBackendEvent_Users value)?  users,TResult Function( BridgeBackendEvent_PageUnavailable value)?  pageUnavailable,TResult Function( BridgeBackendEvent_PrivilegeChanged value)?  privilegeChanged,required TResult orElse(),}){
final _that = this;
switch (_that) {
case BridgeBackendEvent_Capabilities() when capabilities != null:
return capabilities(_that);case BridgeBackendEvent_Applications() when applications != null:
return applications(_that);case BridgeBackendEvent_Processes() when processes != null:
return processes(_that);case BridgeBackendEvent_Performance() when performance != null:
return performance(_that);case BridgeBackendEvent_Cpu() when cpu != null:
return cpu(_that);case BridgeBackendEvent_Gpu() when gpu != null:
return gpu(_that);case BridgeBackendEvent_Network() when network != null:
return network(_that);case BridgeBackendEvent_Users() when users != null:
return users(_that);case BridgeBackendEvent_PageUnavailable() when pageUnavailable != null:
return pageUnavailable(_that);case BridgeBackendEvent_PrivilegeChanged() when privilegeChanged != null:
return privilegeChanged(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( BridgeBackendEvent_Capabilities value)  capabilities,required TResult Function( BridgeBackendEvent_Applications value)  applications,required TResult Function( BridgeBackendEvent_Processes value)  processes,required TResult Function( BridgeBackendEvent_Performance value)  performance,required TResult Function( BridgeBackendEvent_Cpu value)  cpu,required TResult Function( BridgeBackendEvent_Gpu value)  gpu,required TResult Function( BridgeBackendEvent_Network value)  network,required TResult Function( BridgeBackendEvent_Users value)  users,required TResult Function( BridgeBackendEvent_PageUnavailable value)  pageUnavailable,required TResult Function( BridgeBackendEvent_PrivilegeChanged value)  privilegeChanged,}){
final _that = this;
switch (_that) {
case BridgeBackendEvent_Capabilities():
return capabilities(_that);case BridgeBackendEvent_Applications():
return applications(_that);case BridgeBackendEvent_Processes():
return processes(_that);case BridgeBackendEvent_Performance():
return performance(_that);case BridgeBackendEvent_Cpu():
return cpu(_that);case BridgeBackendEvent_Gpu():
return gpu(_that);case BridgeBackendEvent_Network():
return network(_that);case BridgeBackendEvent_Users():
return users(_that);case BridgeBackendEvent_PageUnavailable():
return pageUnavailable(_that);case BridgeBackendEvent_PrivilegeChanged():
return privilegeChanged(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( BridgeBackendEvent_Capabilities value)?  capabilities,TResult? Function( BridgeBackendEvent_Applications value)?  applications,TResult? Function( BridgeBackendEvent_Processes value)?  processes,TResult? Function( BridgeBackendEvent_Performance value)?  performance,TResult? Function( BridgeBackendEvent_Cpu value)?  cpu,TResult? Function( BridgeBackendEvent_Gpu value)?  gpu,TResult? Function( BridgeBackendEvent_Network value)?  network,TResult? Function( BridgeBackendEvent_Users value)?  users,TResult? Function( BridgeBackendEvent_PageUnavailable value)?  pageUnavailable,TResult? Function( BridgeBackendEvent_PrivilegeChanged value)?  privilegeChanged,}){
final _that = this;
switch (_that) {
case BridgeBackendEvent_Capabilities() when capabilities != null:
return capabilities(_that);case BridgeBackendEvent_Applications() when applications != null:
return applications(_that);case BridgeBackendEvent_Processes() when processes != null:
return processes(_that);case BridgeBackendEvent_Performance() when performance != null:
return performance(_that);case BridgeBackendEvent_Cpu() when cpu != null:
return cpu(_that);case BridgeBackendEvent_Gpu() when gpu != null:
return gpu(_that);case BridgeBackendEvent_Network() when network != null:
return network(_that);case BridgeBackendEvent_Users() when users != null:
return users(_that);case BridgeBackendEvent_PageUnavailable() when pageUnavailable != null:
return pageUnavailable(_that);case BridgeBackendEvent_PrivilegeChanged() when privilegeChanged != null:
return privilegeChanged(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( PlatformCapabilities field0)?  capabilities,TResult Function( SnapshotMeta meta,  ApplicationsData data)?  applications,TResult Function( SnapshotMeta meta,  ProcessesData data)?  processes,TResult Function( SnapshotMeta meta,  PerformanceData data)?  performance,TResult Function( SnapshotMeta meta,  CpuData data)?  cpu,TResult Function( SnapshotMeta meta,  GpuData data)?  gpu,TResult Function( SnapshotMeta meta,  NetworkData data)?  network,TResult Function( SnapshotMeta meta,  UsersData data)?  users,TResult Function( PageId page,  SnapshotMeta meta)?  pageUnavailable,TResult Function( PrivilegeResult field0)?  privilegeChanged,required TResult orElse(),}) {final _that = this;
switch (_that) {
case BridgeBackendEvent_Capabilities() when capabilities != null:
return capabilities(_that.field0);case BridgeBackendEvent_Applications() when applications != null:
return applications(_that.meta,_that.data);case BridgeBackendEvent_Processes() when processes != null:
return processes(_that.meta,_that.data);case BridgeBackendEvent_Performance() when performance != null:
return performance(_that.meta,_that.data);case BridgeBackendEvent_Cpu() when cpu != null:
return cpu(_that.meta,_that.data);case BridgeBackendEvent_Gpu() when gpu != null:
return gpu(_that.meta,_that.data);case BridgeBackendEvent_Network() when network != null:
return network(_that.meta,_that.data);case BridgeBackendEvent_Users() when users != null:
return users(_that.meta,_that.data);case BridgeBackendEvent_PageUnavailable() when pageUnavailable != null:
return pageUnavailable(_that.page,_that.meta);case BridgeBackendEvent_PrivilegeChanged() when privilegeChanged != null:
return privilegeChanged(_that.field0);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( PlatformCapabilities field0)  capabilities,required TResult Function( SnapshotMeta meta,  ApplicationsData data)  applications,required TResult Function( SnapshotMeta meta,  ProcessesData data)  processes,required TResult Function( SnapshotMeta meta,  PerformanceData data)  performance,required TResult Function( SnapshotMeta meta,  CpuData data)  cpu,required TResult Function( SnapshotMeta meta,  GpuData data)  gpu,required TResult Function( SnapshotMeta meta,  NetworkData data)  network,required TResult Function( SnapshotMeta meta,  UsersData data)  users,required TResult Function( PageId page,  SnapshotMeta meta)  pageUnavailable,required TResult Function( PrivilegeResult field0)  privilegeChanged,}) {final _that = this;
switch (_that) {
case BridgeBackendEvent_Capabilities():
return capabilities(_that.field0);case BridgeBackendEvent_Applications():
return applications(_that.meta,_that.data);case BridgeBackendEvent_Processes():
return processes(_that.meta,_that.data);case BridgeBackendEvent_Performance():
return performance(_that.meta,_that.data);case BridgeBackendEvent_Cpu():
return cpu(_that.meta,_that.data);case BridgeBackendEvent_Gpu():
return gpu(_that.meta,_that.data);case BridgeBackendEvent_Network():
return network(_that.meta,_that.data);case BridgeBackendEvent_Users():
return users(_that.meta,_that.data);case BridgeBackendEvent_PageUnavailable():
return pageUnavailable(_that.page,_that.meta);case BridgeBackendEvent_PrivilegeChanged():
return privilegeChanged(_that.field0);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( PlatformCapabilities field0)?  capabilities,TResult? Function( SnapshotMeta meta,  ApplicationsData data)?  applications,TResult? Function( SnapshotMeta meta,  ProcessesData data)?  processes,TResult? Function( SnapshotMeta meta,  PerformanceData data)?  performance,TResult? Function( SnapshotMeta meta,  CpuData data)?  cpu,TResult? Function( SnapshotMeta meta,  GpuData data)?  gpu,TResult? Function( SnapshotMeta meta,  NetworkData data)?  network,TResult? Function( SnapshotMeta meta,  UsersData data)?  users,TResult? Function( PageId page,  SnapshotMeta meta)?  pageUnavailable,TResult? Function( PrivilegeResult field0)?  privilegeChanged,}) {final _that = this;
switch (_that) {
case BridgeBackendEvent_Capabilities() when capabilities != null:
return capabilities(_that.field0);case BridgeBackendEvent_Applications() when applications != null:
return applications(_that.meta,_that.data);case BridgeBackendEvent_Processes() when processes != null:
return processes(_that.meta,_that.data);case BridgeBackendEvent_Performance() when performance != null:
return performance(_that.meta,_that.data);case BridgeBackendEvent_Cpu() when cpu != null:
return cpu(_that.meta,_that.data);case BridgeBackendEvent_Gpu() when gpu != null:
return gpu(_that.meta,_that.data);case BridgeBackendEvent_Network() when network != null:
return network(_that.meta,_that.data);case BridgeBackendEvent_Users() when users != null:
return users(_that.meta,_that.data);case BridgeBackendEvent_PageUnavailable() when pageUnavailable != null:
return pageUnavailable(_that.page,_that.meta);case BridgeBackendEvent_PrivilegeChanged() when privilegeChanged != null:
return privilegeChanged(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class BridgeBackendEvent_Capabilities extends BridgeBackendEvent {
  const BridgeBackendEvent_Capabilities(this.field0): super._();


 final  PlatformCapabilities field0;

/// Create a copy of BridgeBackendEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BridgeBackendEvent_CapabilitiesCopyWith<BridgeBackendEvent_Capabilities> get copyWith => _$BridgeBackendEvent_CapabilitiesCopyWithImpl<BridgeBackendEvent_Capabilities>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeBackendEvent_Capabilities&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'BridgeBackendEvent.capabilities(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $BridgeBackendEvent_CapabilitiesCopyWith<$Res> implements $BridgeBackendEventCopyWith<$Res> {
  factory $BridgeBackendEvent_CapabilitiesCopyWith(BridgeBackendEvent_Capabilities value, $Res Function(BridgeBackendEvent_Capabilities) _then) = _$BridgeBackendEvent_CapabilitiesCopyWithImpl;
@useResult
$Res call({
 PlatformCapabilities field0
});




}
/// @nodoc
class _$BridgeBackendEvent_CapabilitiesCopyWithImpl<$Res>
    implements $BridgeBackendEvent_CapabilitiesCopyWith<$Res> {
  _$BridgeBackendEvent_CapabilitiesCopyWithImpl(this._self, this._then);

  final BridgeBackendEvent_Capabilities _self;
  final $Res Function(BridgeBackendEvent_Capabilities) _then;

/// Create a copy of BridgeBackendEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(BridgeBackendEvent_Capabilities(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as PlatformCapabilities,
  ));
}


}

/// @nodoc


class BridgeBackendEvent_Applications extends BridgeBackendEvent {
  const BridgeBackendEvent_Applications({required this.meta, required this.data}): super._();


 final  SnapshotMeta meta;
 final  ApplicationsData data;

/// Create a copy of BridgeBackendEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BridgeBackendEvent_ApplicationsCopyWith<BridgeBackendEvent_Applications> get copyWith => _$BridgeBackendEvent_ApplicationsCopyWithImpl<BridgeBackendEvent_Applications>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeBackendEvent_Applications&&(identical(other.meta, meta) || other.meta == meta)&&(identical(other.data, data) || other.data == data));
}


@override
int get hashCode => Object.hash(runtimeType,meta,data);

@override
String toString() {
  return 'BridgeBackendEvent.applications(meta: $meta, data: $data)';
}


}

/// @nodoc
abstract mixin class $BridgeBackendEvent_ApplicationsCopyWith<$Res> implements $BridgeBackendEventCopyWith<$Res> {
  factory $BridgeBackendEvent_ApplicationsCopyWith(BridgeBackendEvent_Applications value, $Res Function(BridgeBackendEvent_Applications) _then) = _$BridgeBackendEvent_ApplicationsCopyWithImpl;
@useResult
$Res call({
 SnapshotMeta meta, ApplicationsData data
});




}
/// @nodoc
class _$BridgeBackendEvent_ApplicationsCopyWithImpl<$Res>
    implements $BridgeBackendEvent_ApplicationsCopyWith<$Res> {
  _$BridgeBackendEvent_ApplicationsCopyWithImpl(this._self, this._then);

  final BridgeBackendEvent_Applications _self;
  final $Res Function(BridgeBackendEvent_Applications) _then;

/// Create a copy of BridgeBackendEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? meta = null,Object? data = null,}) {
  return _then(BridgeBackendEvent_Applications(
meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as SnapshotMeta,data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as ApplicationsData,
  ));
}


}

/// @nodoc


class BridgeBackendEvent_Processes extends BridgeBackendEvent {
  const BridgeBackendEvent_Processes({required this.meta, required this.data}): super._();


 final  SnapshotMeta meta;
 final  ProcessesData data;

/// Create a copy of BridgeBackendEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BridgeBackendEvent_ProcessesCopyWith<BridgeBackendEvent_Processes> get copyWith => _$BridgeBackendEvent_ProcessesCopyWithImpl<BridgeBackendEvent_Processes>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeBackendEvent_Processes&&(identical(other.meta, meta) || other.meta == meta)&&(identical(other.data, data) || other.data == data));
}


@override
int get hashCode => Object.hash(runtimeType,meta,data);

@override
String toString() {
  return 'BridgeBackendEvent.processes(meta: $meta, data: $data)';
}


}

/// @nodoc
abstract mixin class $BridgeBackendEvent_ProcessesCopyWith<$Res> implements $BridgeBackendEventCopyWith<$Res> {
  factory $BridgeBackendEvent_ProcessesCopyWith(BridgeBackendEvent_Processes value, $Res Function(BridgeBackendEvent_Processes) _then) = _$BridgeBackendEvent_ProcessesCopyWithImpl;
@useResult
$Res call({
 SnapshotMeta meta, ProcessesData data
});




}
/// @nodoc
class _$BridgeBackendEvent_ProcessesCopyWithImpl<$Res>
    implements $BridgeBackendEvent_ProcessesCopyWith<$Res> {
  _$BridgeBackendEvent_ProcessesCopyWithImpl(this._self, this._then);

  final BridgeBackendEvent_Processes _self;
  final $Res Function(BridgeBackendEvent_Processes) _then;

/// Create a copy of BridgeBackendEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? meta = null,Object? data = null,}) {
  return _then(BridgeBackendEvent_Processes(
meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as SnapshotMeta,data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as ProcessesData,
  ));
}


}

/// @nodoc


class BridgeBackendEvent_Performance extends BridgeBackendEvent {
  const BridgeBackendEvent_Performance({required this.meta, required this.data}): super._();


 final  SnapshotMeta meta;
 final  PerformanceData data;

/// Create a copy of BridgeBackendEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BridgeBackendEvent_PerformanceCopyWith<BridgeBackendEvent_Performance> get copyWith => _$BridgeBackendEvent_PerformanceCopyWithImpl<BridgeBackendEvent_Performance>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeBackendEvent_Performance&&(identical(other.meta, meta) || other.meta == meta)&&(identical(other.data, data) || other.data == data));
}


@override
int get hashCode => Object.hash(runtimeType,meta,data);

@override
String toString() {
  return 'BridgeBackendEvent.performance(meta: $meta, data: $data)';
}


}

/// @nodoc
abstract mixin class $BridgeBackendEvent_PerformanceCopyWith<$Res> implements $BridgeBackendEventCopyWith<$Res> {
  factory $BridgeBackendEvent_PerformanceCopyWith(BridgeBackendEvent_Performance value, $Res Function(BridgeBackendEvent_Performance) _then) = _$BridgeBackendEvent_PerformanceCopyWithImpl;
@useResult
$Res call({
 SnapshotMeta meta, PerformanceData data
});




}
/// @nodoc
class _$BridgeBackendEvent_PerformanceCopyWithImpl<$Res>
    implements $BridgeBackendEvent_PerformanceCopyWith<$Res> {
  _$BridgeBackendEvent_PerformanceCopyWithImpl(this._self, this._then);

  final BridgeBackendEvent_Performance _self;
  final $Res Function(BridgeBackendEvent_Performance) _then;

/// Create a copy of BridgeBackendEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? meta = null,Object? data = null,}) {
  return _then(BridgeBackendEvent_Performance(
meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as SnapshotMeta,data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as PerformanceData,
  ));
}


}

/// @nodoc


class BridgeBackendEvent_Cpu extends BridgeBackendEvent {
  const BridgeBackendEvent_Cpu({required this.meta, required this.data}): super._();


 final  SnapshotMeta meta;
 final  CpuData data;

/// Create a copy of BridgeBackendEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BridgeBackendEvent_CpuCopyWith<BridgeBackendEvent_Cpu> get copyWith => _$BridgeBackendEvent_CpuCopyWithImpl<BridgeBackendEvent_Cpu>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeBackendEvent_Cpu&&(identical(other.meta, meta) || other.meta == meta)&&(identical(other.data, data) || other.data == data));
}


@override
int get hashCode => Object.hash(runtimeType,meta,data);

@override
String toString() {
  return 'BridgeBackendEvent.cpu(meta: $meta, data: $data)';
}


}

/// @nodoc
abstract mixin class $BridgeBackendEvent_CpuCopyWith<$Res> implements $BridgeBackendEventCopyWith<$Res> {
  factory $BridgeBackendEvent_CpuCopyWith(BridgeBackendEvent_Cpu value, $Res Function(BridgeBackendEvent_Cpu) _then) = _$BridgeBackendEvent_CpuCopyWithImpl;
@useResult
$Res call({
 SnapshotMeta meta, CpuData data
});




}
/// @nodoc
class _$BridgeBackendEvent_CpuCopyWithImpl<$Res>
    implements $BridgeBackendEvent_CpuCopyWith<$Res> {
  _$BridgeBackendEvent_CpuCopyWithImpl(this._self, this._then);

  final BridgeBackendEvent_Cpu _self;
  final $Res Function(BridgeBackendEvent_Cpu) _then;

/// Create a copy of BridgeBackendEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? meta = null,Object? data = null,}) {
  return _then(BridgeBackendEvent_Cpu(
meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as SnapshotMeta,data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as CpuData,
  ));
}


}

/// @nodoc


class BridgeBackendEvent_Gpu extends BridgeBackendEvent {
  const BridgeBackendEvent_Gpu({required this.meta, required this.data}): super._();


 final  SnapshotMeta meta;
 final  GpuData data;

/// Create a copy of BridgeBackendEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BridgeBackendEvent_GpuCopyWith<BridgeBackendEvent_Gpu> get copyWith => _$BridgeBackendEvent_GpuCopyWithImpl<BridgeBackendEvent_Gpu>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeBackendEvent_Gpu&&(identical(other.meta, meta) || other.meta == meta)&&(identical(other.data, data) || other.data == data));
}


@override
int get hashCode => Object.hash(runtimeType,meta,data);

@override
String toString() {
  return 'BridgeBackendEvent.gpu(meta: $meta, data: $data)';
}


}

/// @nodoc
abstract mixin class $BridgeBackendEvent_GpuCopyWith<$Res> implements $BridgeBackendEventCopyWith<$Res> {
  factory $BridgeBackendEvent_GpuCopyWith(BridgeBackendEvent_Gpu value, $Res Function(BridgeBackendEvent_Gpu) _then) = _$BridgeBackendEvent_GpuCopyWithImpl;
@useResult
$Res call({
 SnapshotMeta meta, GpuData data
});




}
/// @nodoc
class _$BridgeBackendEvent_GpuCopyWithImpl<$Res>
    implements $BridgeBackendEvent_GpuCopyWith<$Res> {
  _$BridgeBackendEvent_GpuCopyWithImpl(this._self, this._then);

  final BridgeBackendEvent_Gpu _self;
  final $Res Function(BridgeBackendEvent_Gpu) _then;

/// Create a copy of BridgeBackendEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? meta = null,Object? data = null,}) {
  return _then(BridgeBackendEvent_Gpu(
meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as SnapshotMeta,data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as GpuData,
  ));
}


}

/// @nodoc


class BridgeBackendEvent_Network extends BridgeBackendEvent {
  const BridgeBackendEvent_Network({required this.meta, required this.data}): super._();


 final  SnapshotMeta meta;
 final  NetworkData data;

/// Create a copy of BridgeBackendEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BridgeBackendEvent_NetworkCopyWith<BridgeBackendEvent_Network> get copyWith => _$BridgeBackendEvent_NetworkCopyWithImpl<BridgeBackendEvent_Network>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeBackendEvent_Network&&(identical(other.meta, meta) || other.meta == meta)&&(identical(other.data, data) || other.data == data));
}


@override
int get hashCode => Object.hash(runtimeType,meta,data);

@override
String toString() {
  return 'BridgeBackendEvent.network(meta: $meta, data: $data)';
}


}

/// @nodoc
abstract mixin class $BridgeBackendEvent_NetworkCopyWith<$Res> implements $BridgeBackendEventCopyWith<$Res> {
  factory $BridgeBackendEvent_NetworkCopyWith(BridgeBackendEvent_Network value, $Res Function(BridgeBackendEvent_Network) _then) = _$BridgeBackendEvent_NetworkCopyWithImpl;
@useResult
$Res call({
 SnapshotMeta meta, NetworkData data
});




}
/// @nodoc
class _$BridgeBackendEvent_NetworkCopyWithImpl<$Res>
    implements $BridgeBackendEvent_NetworkCopyWith<$Res> {
  _$BridgeBackendEvent_NetworkCopyWithImpl(this._self, this._then);

  final BridgeBackendEvent_Network _self;
  final $Res Function(BridgeBackendEvent_Network) _then;

/// Create a copy of BridgeBackendEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? meta = null,Object? data = null,}) {
  return _then(BridgeBackendEvent_Network(
meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as SnapshotMeta,data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as NetworkData,
  ));
}


}

/// @nodoc


class BridgeBackendEvent_Users extends BridgeBackendEvent {
  const BridgeBackendEvent_Users({required this.meta, required this.data}): super._();


 final  SnapshotMeta meta;
 final  UsersData data;

/// Create a copy of BridgeBackendEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BridgeBackendEvent_UsersCopyWith<BridgeBackendEvent_Users> get copyWith => _$BridgeBackendEvent_UsersCopyWithImpl<BridgeBackendEvent_Users>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeBackendEvent_Users&&(identical(other.meta, meta) || other.meta == meta)&&(identical(other.data, data) || other.data == data));
}


@override
int get hashCode => Object.hash(runtimeType,meta,data);

@override
String toString() {
  return 'BridgeBackendEvent.users(meta: $meta, data: $data)';
}


}

/// @nodoc
abstract mixin class $BridgeBackendEvent_UsersCopyWith<$Res> implements $BridgeBackendEventCopyWith<$Res> {
  factory $BridgeBackendEvent_UsersCopyWith(BridgeBackendEvent_Users value, $Res Function(BridgeBackendEvent_Users) _then) = _$BridgeBackendEvent_UsersCopyWithImpl;
@useResult
$Res call({
 SnapshotMeta meta, UsersData data
});




}
/// @nodoc
class _$BridgeBackendEvent_UsersCopyWithImpl<$Res>
    implements $BridgeBackendEvent_UsersCopyWith<$Res> {
  _$BridgeBackendEvent_UsersCopyWithImpl(this._self, this._then);

  final BridgeBackendEvent_Users _self;
  final $Res Function(BridgeBackendEvent_Users) _then;

/// Create a copy of BridgeBackendEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? meta = null,Object? data = null,}) {
  return _then(BridgeBackendEvent_Users(
meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as SnapshotMeta,data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as UsersData,
  ));
}


}

/// @nodoc


class BridgeBackendEvent_PageUnavailable extends BridgeBackendEvent {
  const BridgeBackendEvent_PageUnavailable({required this.page, required this.meta}): super._();


 final  PageId page;
 final  SnapshotMeta meta;

/// Create a copy of BridgeBackendEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BridgeBackendEvent_PageUnavailableCopyWith<BridgeBackendEvent_PageUnavailable> get copyWith => _$BridgeBackendEvent_PageUnavailableCopyWithImpl<BridgeBackendEvent_PageUnavailable>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeBackendEvent_PageUnavailable&&(identical(other.page, page) || other.page == page)&&(identical(other.meta, meta) || other.meta == meta));
}


@override
int get hashCode => Object.hash(runtimeType,page,meta);

@override
String toString() {
  return 'BridgeBackendEvent.pageUnavailable(page: $page, meta: $meta)';
}


}

/// @nodoc
abstract mixin class $BridgeBackendEvent_PageUnavailableCopyWith<$Res> implements $BridgeBackendEventCopyWith<$Res> {
  factory $BridgeBackendEvent_PageUnavailableCopyWith(BridgeBackendEvent_PageUnavailable value, $Res Function(BridgeBackendEvent_PageUnavailable) _then) = _$BridgeBackendEvent_PageUnavailableCopyWithImpl;
@useResult
$Res call({
 PageId page, SnapshotMeta meta
});




}
/// @nodoc
class _$BridgeBackendEvent_PageUnavailableCopyWithImpl<$Res>
    implements $BridgeBackendEvent_PageUnavailableCopyWith<$Res> {
  _$BridgeBackendEvent_PageUnavailableCopyWithImpl(this._self, this._then);

  final BridgeBackendEvent_PageUnavailable _self;
  final $Res Function(BridgeBackendEvent_PageUnavailable) _then;

/// Create a copy of BridgeBackendEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? page = null,Object? meta = null,}) {
  return _then(BridgeBackendEvent_PageUnavailable(
page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as PageId,meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as SnapshotMeta,
  ));
}


}

/// @nodoc


class BridgeBackendEvent_PrivilegeChanged extends BridgeBackendEvent {
  const BridgeBackendEvent_PrivilegeChanged(this.field0): super._();


 final  PrivilegeResult field0;

/// Create a copy of BridgeBackendEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BridgeBackendEvent_PrivilegeChangedCopyWith<BridgeBackendEvent_PrivilegeChanged> get copyWith => _$BridgeBackendEvent_PrivilegeChangedCopyWithImpl<BridgeBackendEvent_PrivilegeChanged>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeBackendEvent_PrivilegeChanged&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'BridgeBackendEvent.privilegeChanged(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $BridgeBackendEvent_PrivilegeChangedCopyWith<$Res> implements $BridgeBackendEventCopyWith<$Res> {
  factory $BridgeBackendEvent_PrivilegeChangedCopyWith(BridgeBackendEvent_PrivilegeChanged value, $Res Function(BridgeBackendEvent_PrivilegeChanged) _then) = _$BridgeBackendEvent_PrivilegeChangedCopyWithImpl;
@useResult
$Res call({
 PrivilegeResult field0
});




}
/// @nodoc
class _$BridgeBackendEvent_PrivilegeChangedCopyWithImpl<$Res>
    implements $BridgeBackendEvent_PrivilegeChangedCopyWith<$Res> {
  _$BridgeBackendEvent_PrivilegeChangedCopyWithImpl(this._self, this._then);

  final BridgeBackendEvent_PrivilegeChanged _self;
  final $Res Function(BridgeBackendEvent_PrivilegeChanged) _then;

/// Create a copy of BridgeBackendEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(BridgeBackendEvent_PrivilegeChanged(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as PrivilegeResult,
  ));
}


}

// dart format on
