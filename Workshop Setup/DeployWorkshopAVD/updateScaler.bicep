param hostPoolScalePlanName string

//Pull in the scaler
resource scalingPlan 'Microsoft.DesktopVirtualization/scalingPlans@2022-09-09' existing = {
  name: hostPoolScalePlanName
}

//Set up the scaling plan for that week.
resource scalingSchedule 'Microsoft.DesktopVirtualization/scalingPlans/pooledSchedules@2022-09-09' = {
  name: 'lbgWorkshopSchedule'
  parent: scalingPlan
  properties: {
    daysOfWeek: [
      'Monday'
      'Tuesday'
      'Wednesday'
      'Thursday'
      'Friday'
    ]
    rampUpStartTime: {
      hour: 8
      minute: 0
    }
    peakStartTime: {
        hour: 9
        minute: 0
    }
    rampDownStartTime: {
        hour: 18
        minute: 0
    }
    offPeakStartTime: {
        hour: 19
        minute: 0
    }
    rampUpLoadBalancingAlgorithm: 'BreadthFirst' //Load balance across available hosts (ramp up time)
    rampUpMinimumHostsPct: 20       //This is the minimum number of hosts to be running at any time (during ramp up).  So if 10 hosts, 2 will be on (20%) at all times
    rampUpCapacityThresholdPct: 80  //This is the capacity of the host pool that will trigger the ramp up.  So 2 hosts with 5/users per host, at 6 users, another host will be started
    peakLoadBalancingAlgorithm: 'BreadthFirst'  //Local balance across available hosts (peak time)
    rampDownLoadBalancingAlgorithm: 'DepthFirst'  //Fill existing hosts to capacity before moving on to next host (ramp down time) - consolidation
    rampDownMinimumHostsPct: 0   //This is the minimum number of hosts to be running at any time (during ramp down).  In this case ramp down to Zero (i.e. zero during offpeak)
    rampDownCapacityThresholdPct: 90  //This is the capacity of the host pool that will trigger the ramp down.  So 2 hosts with 5/users per host, at 9 users, another host will be started (a high threshold to prevent additional hosts starting unneccessarily)
    rampDownForceLogoffUsers: true //This will force users to log off when the host pool is scaled down if set to true (if false, relies on user logoff or GPO logging them out)
    rampDownWaitTimeMinutes: 30  //How long the user is given before they are kicked out of the session
    rampDownNotificationMessage: 'You will be logged off in 30 min. Make sure to save your work.'  //The message the user will get
    rampDownStopHostsWhen: 'ZeroSessions'  //When to stop a host.  In this case when there are no users connected (zero sessions)
    offPeakLoadBalancingAlgorithm: 'DepthFirst'  //Fill existing hosts to capacity before moving on to next host (ramp down time) - consolidation
  }
}
