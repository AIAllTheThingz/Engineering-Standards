using System;
using Example.Service;

namespace Example.Service.Tests;

public sealed class HealthReporterTests
{
    public void GetStatus_ReturnsHealthy()
    {
        var reporter = new HealthReporter();
        if (reporter.GetStatus() != "Healthy")
        {
            throw new InvalidOperationException("Expected Healthy status.");
        }
    }
}
