import {
  CheckCircleOutlineRounded,
  CloseRounded,
  DirectionsCarOutlined,
  LogoutRounded,
  RefreshRounded,
  VerifiedRounded,
} from '@mui/icons-material';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';

import {
  getAdminVehicleReviews,
  reviewAdminVehicle,
  type AdminVehicleReview,
} from '../../../api/admin/adminVehicleReviewsApi';
import type { VehicleApprovalStatus } from '../../../api/provider/providerFleetApi';
import { clearSession } from '../../../core/session';

import './AdminVehicleReviewsPage.css';

const TABS: VehicleApprovalStatus[] = ['Pending', 'Approved', 'Rejected'];

function vehicleName(review: AdminVehicleReview): string {
  return [review.car?.brand, review.car?.model].filter(Boolean).join(' ') || 'Vehicle';
}

function dateLabel(value?: string): string {
  if (!value) return 'Not provided';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return 'Not provided';
  return new Intl.DateTimeFormat('en', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  }).format(date);
}

export default function AdminVehicleReviewsPage() {
  const [status, setStatus] = useState<VehicleApprovalStatus>('Pending');
  const [rejecting, setRejecting] = useState<AdminVehicleReview | null>(null);
  const [notice, setNotice] = useState('');
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  const reviewsQuery = useQuery({
    queryKey: ['admin', 'vehicle-reviews', status],
    queryFn: () => getAdminVehicleReviews(status),
  });

  const reviewMutation = useMutation({
    mutationFn: ({
      review,
      decision,
      reason,
    }: {
      review: AdminVehicleReview;
      decision: 'Approved' | 'Rejected';
      reason?: string;
    }) => reviewAdminVehicle(review._id, decision, reason),
    onSuccess: async (message) => {
      setNotice(message);
      setRejecting(null);
      await queryClient.invalidateQueries({
        queryKey: ['admin', 'vehicle-reviews'],
      });
    },
  });

  function signOut() {
    clearSession();
    navigate('/login', { replace: true });
  }

  return (
    <main className="admin-vehicle-page">
      <header className="admin-vehicle-topbar">
        <div><DirectionsCarOutlined /><strong>DiamondCar</strong><span>Admin</span></div>
        <button type="button" onClick={signOut}><LogoutRounded />Sign out</button>
      </header>

      <div className="admin-vehicle-content">
        <section className="admin-vehicle-heading">
          <div><h1>Vehicle approvals</h1><p>Verify provider vehicles before they become visible to renters.</p></div>
          <button type="button" disabled={reviewsQuery.isFetching} onClick={() => void reviewsQuery.refetch()}><RefreshRounded />{reviewsQuery.isFetching ? 'Refreshing…' : 'Refresh'}</button>
        </section>

        {notice && <div className="admin-vehicle-notice" role="status"><CheckCircleOutlineRounded />{notice}<button type="button" onClick={() => setNotice('')}><CloseRounded /></button></div>}
        {reviewMutation.isError && <div className="admin-vehicle-error" role="alert">{reviewMutation.error.message}</div>}

        <nav className="admin-vehicle-tabs" aria-label="Review status">
          {TABS.map((tab) => <button key={tab} type="button" className={status === tab ? `active ${tab.toLowerCase()}` : ''} onClick={() => { setStatus(tab); setNotice(''); }}>{tab}</button>)}
        </nav>

        {reviewsQuery.isPending ? (
          <div className="admin-vehicle-state">Loading vehicle reviews…</div>
        ) : reviewsQuery.isError ? (
          <div className="admin-vehicle-state"><h2>Reviews unavailable</h2><p>{reviewsQuery.error.message}</p><button type="button" onClick={() => void reviewsQuery.refetch()}>Try again</button></div>
        ) : reviewsQuery.data.length === 0 ? (
          <div className="admin-vehicle-state"><CheckCircleOutlineRounded /><h2>No {status.toLowerCase()} vehicles</h2><p>{status === 'Pending' ? 'The review queue is clear.' : `Reviewed vehicles will appear here.`}</p></div>
        ) : (
          <section className="admin-vehicle-grid">
            {reviewsQuery.data.map((review) => (
              <VehicleReviewCard
                key={review._id}
                review={review}
                pending={reviewMutation.isPending}
                onApprove={() => reviewMutation.mutate({ review, decision: 'Approved' })}
                onReject={() => setRejecting(review)}
              />
            ))}
          </section>
        )}
      </div>

      {rejecting && (
        <RejectDialog
          review={rejecting}
          loading={reviewMutation.isPending}
          error={reviewMutation.isError ? reviewMutation.error.message : ''}
          onClose={() => setRejecting(null)}
          onConfirm={(reason) =>
            reviewMutation.mutate({
              review: rejecting,
              decision: 'Rejected',
              reason,
            })
          }
        />
      )}
    </main>
  );
}

function VehicleReviewCard({
  review,
  pending,
  onApprove,
  onReject,
}: {
  review: AdminVehicleReview;
  pending: boolean;
  onApprove: () => void;
  onReject: () => void;
}) {
  const car = review.car;
  const provider = review.provider;
  const images = review.images?.filter(Boolean) ?? [];
  const [activeImageIndex, setActiveImageIndex] = useState(0);
  const activeImage = images[activeImageIndex];
  return (
    <article className="admin-vehicle-card">
      <div className="admin-vehicle-gallery">
        {activeImage ? <img src={activeImage} alt={`${vehicleName(review)} photo ${activeImageIndex + 1}`} /> : <DirectionsCarOutlined />}
        <span className={review.approvalStatus.toLowerCase()}>{review.approvalStatus}</span>
        <small>{images.length} photos</small>
      </div>
      {images.length > 1 && (
        <div className="admin-vehicle-thumbnails">
          {images.map((image, index) => (
            <button
              key={`${image}-${index}`}
              type="button"
              className={index === activeImageIndex ? 'active' : ''}
              aria-label={`View vehicle photo ${index + 1}`}
              onClick={() => setActiveImageIndex(index)}
            >
              <img src={image} alt="" />
            </button>
          ))}
        </div>
      )}
      <div className="admin-vehicle-card-body">
        <header><div><h2>{vehicleName(review)}</h2><p>{car?.year} · {car?.category} · {car?.transmission} · {car?.fuelType}</p></div><strong>{review.registrationNumber}</strong></header>
        <dl>
          <div><dt>Color</dt><dd>{review.color || '—'}</dd></div>
          <div><dt>Seats</dt><dd>{car?.seats ?? '—'}</dd></div>
          <div><dt>Daily price</dt><dd>AED {review.rentalPricePerDay ?? 0}</dd></div>
          <div><dt>Deposit</dt><dd>AED {review.depositAmount ?? 0}</dd></div>
          <div><dt>Insurance</dt><dd>{review.insuranceDetails?.insuranceCompany || '—'}</dd></div>
          <div><dt>Policy</dt><dd>{review.insuranceDetails?.policyNumber || '—'}</dd></div>
          <div><dt>Policy expiry</dt><dd>{dateLabel(review.insuranceDetails?.expiryDate)}</dd></div>
          <div><dt>Submitted</dt><dd>{dateLabel(review.submittedAt)}</dd></div>
        </dl>
        <section className="admin-vehicle-provider">
          {provider?.profilePicture ? <img src={provider.profilePicture} alt="" /> : <span>{provider?.companyName?.charAt(0) || 'P'}</span>}
          <div><strong>{provider?.companyName || 'Provider'}</strong><small>{provider?.contactPerson?.name || provider?.email || 'No contact'}</small></div>
          {provider?.isVerified && <VerifiedRounded />}
        </section>
        {review.rejectionReason && <p className="admin-vehicle-reason"><b>Rejection reason:</b> {review.rejectionReason}</p>}
        {review.approvalStatus === 'Pending' && (
          <footer><button type="button" className="reject" disabled={pending} onClick={onReject}>Reject</button><button type="button" className="approve" disabled={pending} onClick={onApprove}>Approve vehicle</button></footer>
        )}
      </div>
    </article>
  );
}

function RejectDialog({
  review,
  loading,
  error,
  onClose,
  onConfirm,
}: {
  review: AdminVehicleReview;
  loading: boolean;
  error: string;
  onClose: () => void;
  onConfirm: (reason: string) => void;
}) {
  const [reason, setReason] = useState('');
  const invalid = reason.trim().length < 5;
  return (
    <div className="admin-vehicle-dialog-backdrop">
      <section className="admin-vehicle-dialog" role="dialog" aria-modal="true" aria-labelledby="reject-vehicle-title">
        <button type="button" className="close" disabled={loading} onClick={onClose}><CloseRounded /></button>
        <h2 id="reject-vehicle-title">Reject {vehicleName(review)}?</h2>
        <p>Tell the provider exactly what must be corrected before resubmitting.</p>
        {error && <div className="admin-vehicle-dialog-error" role="alert">{error}</div>}
        <label><span>Rejection reason *</span><textarea autoFocus rows={5} value={reason} onChange={(event) => setReason(event.target.value)} placeholder="Example: The registration number is not visible in the uploaded photos." /></label>
        <footer><button type="button" disabled={loading} onClick={onClose}>Cancel</button><button type="button" className="reject" disabled={loading || invalid} onClick={() => onConfirm(reason.trim())}>{loading ? 'Saving…' : 'Reject vehicle'}</button></footer>
      </section>
    </div>
  );
}
