namespace Gaku.Application.Interfaces;

/// <summary>
/// Abstracts a single database transaction boundary so Application-layer services
/// can flush changes without taking a direct dependency on EF Core.
/// </summary>
public interface IUnitOfWork
{
    /// <summary>Commits all pending changes to the database and returns the number of affected rows.</summary>
    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
