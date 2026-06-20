using System;
using Example.Service;

namespace Example.Service.Tests;

public sealed class HealthReporterTests
{
    public static void Main()
    {
        new HealthReporterTests().GetStatus_ReturnsHealthy();
        Console.WriteLine("HealthReporter tests passed.");
    }

    public void GetStatus_ReturnsHealthy()
    {
        var reporter = new HealthReporter();
        if (reporter.GetStatus() != "Healthy")
        {
            throw new InvalidOperationException("Expected Healthy status.");
        }
    }
}
