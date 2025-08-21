part of 'dashboard_cubit.dart';

abstract class DashboardState extends Equatable {
  const DashboardState();
}

class DashboardInitial extends DashboardState {
  @override
  List<Object> get props => [];
}

class DashboardLoading extends DashboardState {
  @override
  List<Object> get props => [];
}

class DashboardSuccess extends DashboardState {
  final DashboardModel dashboardModel;

  const DashboardSuccess(this.dashboardModel);

  @override
  List<Object> get props => [dashboardModel];
}

class DashboardFailure extends DashboardState {
  final String msg;

  const DashboardFailure(this.msg);

  @override
  List<Object> get props => [msg];
}
