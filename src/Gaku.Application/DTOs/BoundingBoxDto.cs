namespace Gaku.Application.DTOs;

public record BoundingBoxDto(
    double MinLatitude,
    double MinLongitude,
    double MaxLatitude,
    double MaxLongitude);
