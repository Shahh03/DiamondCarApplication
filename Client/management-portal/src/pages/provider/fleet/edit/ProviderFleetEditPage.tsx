
import {
  ArrowBackRounded,
  CloudUploadOutlined,
  DeleteOutlineRounded,
  DirectionsCarOutlined,
  DragIndicatorRounded,
  SaveRounded,
} from '@mui/icons-material';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import {
  useEffect,
  useRef,
  useState,
  type ChangeEvent,
  type DragEvent,
  type FormEvent,
  type ReactNode,
} from 'react';
import { flushSync } from 'react-dom';
import { Link, useNavigate, useParams } from 'react-router-dom';

import {
  getProviderFleet,
  removeProviderFleetVehicleImage,
  reorderProviderFleetVehicleImages,
  submitProviderFleetVehicleForReview,
  updateProviderFleetVehicle,
  uploadProviderFleetVehicleImages,
  type ProviderFleetVehicle,
  type UpdateProviderFleetVehicleInput,
} from '../../../../api/provider/providerFleetApi';
import { readSession } from '../../../../core/session';

import './ProviderFleetEditPage.css';

interface VehicleEditForm {
  color: string;
  registrationNumber: string;
  rentalPricePerDay: string;
  depositAmount: string;
  isAvailable: boolean;
  insuranceCompany: string;
  policyNumber: string;
  expiryDate: string;
}

interface ExistingPhoto {
  id: string;
  kind: 'existing';
  url: string;
}

interface PendingPhoto {
  id: string;
  kind: 'pending';
  file: File;
  url: string;
}

type PhotoItem = ExistingPhoto | PendingPhoto;

function photoId(prefix: string): string {
  return `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2)}`;
}

function dateInputValue(value?: string): string {
  if (!value) return '';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '';
  return date.toISOString().slice(0, 10);
}

function formFromVehicle(vehicle: ProviderFleetVehicle): VehicleEditForm {
  return {
    color: vehicle.color ?? '',
    registrationNumber: vehicle.registrationNumber ?? '',
    rentalPricePerDay: String(vehicle.rentalPricePerDay ?? ''),
    depositAmount: String(vehicle.depositAmount ?? ''),
    isAvailable: vehicle.isAvailable !== false,
    insuranceCompany: vehicle.insuranceDetails?.insuranceCompany ?? '',
    policyNumber: vehicle.insuranceDetails?.policyNumber ?? '',
    expiryDate: dateInputValue(vehicle.insuranceDetails?.expiryDate),
  };
}

function vehicleName(vehicle: ProviderFleetVehicle): string {
  return [vehicle.car?.brand, vehicle.car?.model]
    .filter(Boolean)
    .join(' ') || 'Vehicle';
}

function trimmedOrUndefined(value: string): string | undefined {
  const trimmed = value.trim();
  return trimmed || undefined;
}

export default function ProviderFleetEditPage() {
  const { vehicleId = '' } = useParams();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const providerId = readSession()?.user._id ?? '';

  const [form, setForm] = useState<VehicleEditForm | null>(null);
  const [loadedVehicleId, setLoadedVehicleId] = useState<string | null>(null);
  const [photoItems, setPhotoItems] = useState<PhotoItem[]>([]);
  const [draggedPhotoId, setDraggedPhotoId] = useState<string | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const previewUrls = useRef(new Set<string>());
  const photoElements = useRef(new Map<string, HTMLElement>());
  const lastDragTargetId = useRef<string | null>(null);

  const fleetQuery = useQuery({
    queryKey: ['provider', providerId, 'fleet'],
    queryFn: () => getProviderFleet(providerId),
    enabled: Boolean(providerId),
  });

  const vehicle = fleetQuery.data?.vehicles.find(
    (item) => item._id === vehicleId,
  );

  useEffect(() => {
    if (vehicle && loadedVehicleId !== vehicle._id) {
      setForm(formFromVehicle(vehicle));
      setPhotoItems(
        (vehicle.images ?? []).map((url, index) => ({
          id: `existing-${index}-${url}`,
          kind: 'existing' as const,
          url,
        })),
      );
      setLoadedVehicleId(vehicle._id);
    }
  }, [loadedVehicleId, vehicle]);

  useEffect(() => {
    return () => {
      previewUrls.current.forEach((url) => URL.revokeObjectURL(url));
      previewUrls.current.clear();
    };
  }, []);

  const saveMutation = useMutation({
    mutationFn: async (input: UpdateProviderFleetVehicleInput) => {
      await updateProviderFleetVehicle(vehicleId, input);

      const pendingPhotos = photoItems.filter(
        (photo): photo is PendingPhoto => photo.kind === 'pending',
      );
      let resolvedPhotos: ExistingPhoto[] = photoItems.filter(
        (photo): photo is ExistingPhoto => photo.kind === 'existing',
      );

      if (pendingPhotos.length > 0) {
        const uploadedImages = await uploadProviderFleetVehicleImages(
          vehicleId,
          pendingPhotos.map((photo) => photo.file),
        );
        const uploadedUrls = uploadedImages.slice(-pendingPhotos.length);

        if (uploadedUrls.length !== pendingPhotos.length) {
          throw new Error('The server did not return every uploaded photo.');
        }

        const uploadedByPhotoId = new Map(
          pendingPhotos.map((photo, index) => [photo.id, uploadedUrls[index]]),
        );

        resolvedPhotos = photoItems.map((photo) => {
          if (photo.kind === 'existing') return photo;

          const uploadedUrl = uploadedByPhotoId.get(photo.id);
          if (!uploadedUrl) {
            throw new Error('Could not match an uploaded photo to its order.');
          }

          URL.revokeObjectURL(photo.url);
          previewUrls.current.delete(photo.url);

          return {
            id: `existing-uploaded-${photo.id}`,
            kind: 'existing' as const,
            url: uploadedUrl,
          };
        });

        setPhotoItems(resolvedPhotos);
      }

      await reorderProviderFleetVehicleImages(
        vehicleId,
        resolvedPhotos.map((photo) => photo.url),
      );

      if (vehicle?.approvalStatus === 'Rejected') {
        await submitProviderFleetVehicleForReview(vehicleId);
      }
    },
    onSuccess: async () => {
      await queryClient.invalidateQueries({
        queryKey: ['provider', providerId, 'fleet'],
      });
      navigate('/provider/fleet', { replace: true });
    },
  });

  const removeImageMutation = useMutation({
    mutationFn: (imageUrl: string) =>
      removeProviderFleetVehicleImage(vehicleId, imageUrl),
    onSuccess: async (_images, removedImageUrl) => {
      setPhotoItems((current) =>
        current.filter(
          (photo) =>
            photo.kind !== 'existing' || photo.url !== removedImageUrl,
        ),
      );
      await queryClient.invalidateQueries({
        queryKey: ['provider', providerId, 'fleet'],
      });
    },
  });

  function updateField<Key extends keyof VehicleEditForm>(
    key: Key,
    value: VehicleEditForm[Key],
  ) {
    setForm((current) => current ? { ...current, [key]: value } : current);
    setFormError(null);
  }

  function selectPhotos(event: ChangeEvent<HTMLInputElement>) {
    const selected = Array.from(event.target.files ?? []).filter((file) =>
      file.type.startsWith('image/'),
    );
    event.target.value = '';

    if (!selected.length) return;

    const remainingSlots = Math.max(0, 10 - photoItems.length);

    if (selected.length > remainingSlots) {
      setFormError(
        remainingSlots === 0
          ? 'This vehicle already has the maximum of 10 photos.'
          : `You can add only ${remainingSlots} more photo${remainingSlots === 1 ? '' : 's'}.`,
      );
      return;
    }

    const nextPhotos: PendingPhoto[] = selected.map((file) => {
      const url = URL.createObjectURL(file);
      previewUrls.current.add(url);

      return {
        id: photoId('pending'),
        kind: 'pending',
        file,
        url,
      };
    });

    setPhotoItems((current) => [...current, ...nextPhotos]);
    setFormError(null);
  }

  function removePendingPhoto(photoIdToRemove: string) {
    setPhotoItems((current) => {
      const photo = current.find((item) => item.id === photoIdToRemove);
      if (photo?.kind === 'pending') {
        URL.revokeObjectURL(photo.url);
        previewUrls.current.delete(photo.url);
      }

      return current.filter((item) => item.id !== photoIdToRemove);
    });
  }

  function removeExistingPhoto(imageUrl: string) {
    const confirmed = window.confirm(
      'Remove this photo from the vehicle? This cannot be undone.',
    );
    if (confirmed) removeImageMutation.mutate(imageUrl);
  }

  function animatePhotoReorder(
    reorder: (current: PhotoItem[]) => PhotoItem[],
    movingPhotoId?: string,
  ) {
    const previousPositions = new Map<string, DOMRect>();
    photoElements.current.forEach((element, id) => {
      previousPositions.set(id, element.getBoundingClientRect());
    });

    flushSync(() => {
      setPhotoItems(reorder);
    });

    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

    photoElements.current.forEach((element, id) => {
      if (id === movingPhotoId) return;

      const previousPosition = previousPositions.get(id);
      if (!previousPosition) return;

      const nextPosition = element.getBoundingClientRect();
      const horizontalDistance = previousPosition.left - nextPosition.left;
      const verticalDistance = previousPosition.top - nextPosition.top;

      if (horizontalDistance === 0 && verticalDistance === 0) return;

      element.getAnimations().forEach((animation) => animation.cancel());
      element.animate(
        [
          {
            transform: `translate(${horizontalDistance}px, ${verticalDistance}px)`,
          },
          { transform: 'translate(0, 0)' },
        ],
        {
          duration: 220,
          easing: 'cubic-bezier(0.22, 1, 0.36, 1)',
        },
      );
    });
  }

  function movePhoto(sourceId: string, targetId: string) {
    if (sourceId === targetId) return;

    animatePhotoReorder((current) => {
      const sourceIndex = current.findIndex((photo) => photo.id === sourceId);
      const targetIndex = current.findIndex((photo) => photo.id === targetId);
      if (sourceIndex < 0 || targetIndex < 0) return current;

      const reordered = [...current];
      const [movedPhoto] = reordered.splice(sourceIndex, 1);
      if (!movedPhoto) return current;
      reordered.splice(targetIndex, 0, movedPhoto);
      return reordered;
    }, sourceId);
  }

  function startPhotoDrag(
    event: DragEvent<HTMLElement>,
    photoIdToMove: string,
  ) {
    setDraggedPhotoId(photoIdToMove);
    lastDragTargetId.current = null;
    event.dataTransfer.effectAllowed = 'move';
    event.dataTransfer.setData('text/plain', photoIdToMove);
  }

  function enterPhotoDropZone(
    event: DragEvent<HTMLElement>,
    targetPhotoId: string,
  ) {
    event.preventDefault();
    const sourceId =
      draggedPhotoId || event.dataTransfer.getData('text/plain');
    if (!sourceId || lastDragTargetId.current === targetPhotoId) return;

    lastDragTargetId.current = targetPhotoId;
    movePhoto(sourceId, targetPhotoId);
  }

  function dropPhoto(event: DragEvent<HTMLElement>) {
    event.preventDefault();
    lastDragTargetId.current = null;
    setDraggedPhotoId(null);
  }

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!form) return;

    const color = form.color.trim();
    const registrationNumber = form.registrationNumber.trim();
    const rentalPricePerDay = Number(form.rentalPricePerDay);
    const depositAmount = Number(form.depositAmount);

    if (!color || !registrationNumber) {
      setFormError('Color and registration number are required.');
      return;
    }

    if (!Number.isFinite(rentalPricePerDay) || rentalPricePerDay < 0) {
      setFormError('Price per day must be zero or greater.');
      return;
    }

    if (!Number.isFinite(depositAmount) || depositAmount < 0) {
      setFormError('Deposit must be zero or greater.');
      return;
    }

    setFormError(null);
    saveMutation.mutate({
      color,
      registrationNumber,
      rentalPricePerDay,
      depositAmount,
      isAvailable: form.isAvailable,
      insuranceDetails: {
        insuranceCompany: trimmedOrUndefined(form.insuranceCompany),
        policyNumber: trimmedOrUndefined(form.policyNumber),
        expiryDate: trimmedOrUndefined(form.expiryDate),
      },
    });
  }

  if (fleetQuery.isPending) {
    return (
      <main className="provider-fleet-edit-page" aria-busy="true">
        <div className="provider-fleet-edit-loading"><span /></div>
      </main>
    );
  }

  if (fleetQuery.isError) {
    return (
      <main className="provider-fleet-edit-page">
        <EditState
          title="Vehicle unavailable"
          message={fleetQuery.error.message}
          actionLabel="Try again"
          onAction={() => void fleetQuery.refetch()}
        />
      </main>
    );
  }

  if (!vehicle || !form) {
    return (
      <main className="provider-fleet-edit-page">
        <EditState
          title="Vehicle not found"
          message="This vehicle is not part of your active fleet."
          actionLabel="Back to Fleet"
          onAction={() => navigate('/provider/fleet', { replace: true })}
        />
      </main>
    );
  }

  const displayedError =
    formError ||
    (saveMutation.error instanceof Error ? saveMutation.error.message : null) ||
    (removeImageMutation.error instanceof Error
      ? removeImageMutation.error.message
      : null);
  const busy = saveMutation.isPending || removeImageMutation.isPending;

  return (
    <main className="provider-fleet-edit-page">
      <header className="provider-fleet-edit-heading">
        <div>
          <Link to="/provider/fleet">
            <ArrowBackRounded />
            Back to Fleet
          </Link>
          <h1>Edit {vehicleName(vehicle)}</h1>
          <p>Update this vehicle’s listing, pricing, insurance and photos.</p>
        </div>

        <div className="provider-fleet-edit-heading-actions">
          <Link className="provider-fleet-edit-cancel" to="/provider/fleet">
            Cancel
          </Link>
          <button
            className="provider-fleet-edit-save"
            type="submit"
            form="provider-fleet-edit-form"
            disabled={busy}
          >
            <SaveRounded />
            {saveMutation.isPending
              ? vehicle.approvalStatus === 'Rejected'
                ? 'Saving & resubmitting…'
                : 'Saving…'
              : vehicle.approvalStatus === 'Rejected'
                ? 'Save & Resubmit for Review'
                : 'Save Changes'}
          </button>
        </div>
      </header>

      {displayedError && (
        <div className="provider-fleet-edit-alert" role="alert">
          {displayedError}
        </div>
      )}

      {vehicle.approvalStatus && vehicle.approvalStatus !== 'Approved' && (
        <div
          className={`provider-fleet-edit-review ${vehicle.approvalStatus.toLowerCase()}`}
        >
          <strong>
            {vehicle.approvalStatus === 'Pending'
              ? 'Pending admin review'
              : 'Changes required before approval'}
          </strong>
          <p>
            {vehicle.approvalStatus === 'Rejected'
              ? vehicle.rejectionReason || 'Review and correct the vehicle details before resubmitting it.'
              : 'This vehicle is not visible to renters until an admin approves it.'}
          </p>
          {vehicle.approvalStatus === 'Rejected' && (
            <small>
              Make the requested corrections below. Your changes will be saved
              before the vehicle is resubmitted to the admin.
            </small>
          )}
        </div>
      )}

      <form
        id="provider-fleet-edit-form"
        className="provider-fleet-edit-layout"
        onSubmit={submit}
      >
        <div className="provider-fleet-edit-main">
          <EditSection
            title="Vehicle model"
            description="These details belong to the shared vehicle model and are read-only."
          >
            <dl className="provider-fleet-edit-readonly-grid">
              <ReadOnlyDetail label="Brand" value={vehicle.car?.brand} />
              <ReadOnlyDetail label="Model" value={vehicle.car?.model} />
              <ReadOnlyDetail label="Year" value={vehicle.car?.year} />
              <ReadOnlyDetail label="Category" value={vehicle.car?.category} />
              <ReadOnlyDetail label="Transmission" value={vehicle.car?.transmission} />
              <ReadOnlyDetail label="Fuel type" value={vehicle.car?.fuelType} />
              <ReadOnlyDetail label="Seats" value={vehicle.car?.seats} />
            </dl>
          </EditSection>

          <EditSection
            title="Listing details"
            description="Edit the information specific to this vehicle in your fleet."
          >
            <div className="provider-fleet-edit-fields">
              <EditField label="Registration number" required>
                <input
                  value={form.registrationNumber}
                  onChange={(event) =>
                    updateField('registrationNumber', event.target.value)
                  }
                />
              </EditField>

              <EditField label="Color" required>
                <input
                  value={form.color}
                  onChange={(event) => updateField('color', event.target.value)}
                />
              </EditField>

              <EditField label="Price per day" required>
                <input
                  type="number"
                  min="0"
                  step="0.01"
                  value={form.rentalPricePerDay}
                  onChange={(event) =>
                    updateField('rentalPricePerDay', event.target.value)
                  }
                />
              </EditField>

              <EditField label="Deposit" required>
                <input
                  type="number"
                  min="0"
                  step="0.01"
                  value={form.depositAmount}
                  onChange={(event) =>
                    updateField('depositAmount', event.target.value)
                  }
                />
              </EditField>
            </div>

            <label className="provider-fleet-edit-availability">
              <input
                type="checkbox"
                checked={form.isAvailable}
                onChange={(event) =>
                  updateField('isAvailable', event.target.checked)
                }
              />
              <span>
                <strong>Listed for renters</strong>
                <small>
                  Turn this off to hide the vehicle from the renter marketplace.
                  Admin approval is still required before it becomes visible.
                </small>
              </span>
            </label>
          </EditSection>

          <EditSection
            title="Insurance"
            description="Keep the vehicle’s insurance details up to date."
          >
            <div className="provider-fleet-edit-fields">
              <EditField label="Insurance company">
                <input
                  value={form.insuranceCompany}
                  onChange={(event) =>
                    updateField('insuranceCompany', event.target.value)
                  }
                />
              </EditField>

              <EditField label="Policy number">
                <input
                  value={form.policyNumber}
                  onChange={(event) =>
                    updateField('policyNumber', event.target.value)
                  }
                />
              </EditField>

              <EditField label="Expiry date">
                <input
                  type="date"
                  value={form.expiryDate}
                  onChange={(event) =>
                    updateField('expiryDate', event.target.value)
                  }
                />
              </EditField>
            </div>
          </EditSection>
        </div>

        <aside className="provider-fleet-edit-photos">
          <header>
            <div>
              <h2>Vehicle photos</h2>
              <p>{photoItems.length} of 10 photos</p>
            </div>

            <label className={photoItems.length >= 10 ? 'disabled' : ''}>
              <CloudUploadOutlined />
              Add photos
              <input
                type="file"
                accept="image/*"
                multiple
                disabled={photoItems.length >= 10 || busy}
                onChange={selectPhotos}
              />
            </label>
          </header>

          <div className="provider-fleet-edit-photo-grid">
            {photoItems.map((photo, index) => (
              <figure
                key={photo.id}
                ref={(element) => {
                  if (element) {
                    photoElements.current.set(photo.id, element);
                  } else {
                    photoElements.current.delete(photo.id);
                  }
                }}
                className={[
                  photo.kind === 'pending' ? 'pending' : '',
                  draggedPhotoId === photo.id ? 'dragging' : '',
                ].filter(Boolean).join(' ')}
                draggable={!busy}
                onDragStart={(event) => startPhotoDrag(event, photo.id)}
                onDragOver={(event) => {
                  event.preventDefault();
                  event.dataTransfer.dropEffect = 'move';
                }}
                onDragEnter={(event) => enterPhotoDropZone(event, photo.id)}
                onDrop={dropPhoto}
                onDragEnd={() => {
                  lastDragTargetId.current = null;
                  setDraggedPhotoId(null);
                }}
              >
                <img
                  src={photo.url}
                  alt={`${vehicleName(vehicle)} ${index + 1}`}
                />

                <span
                  className="provider-fleet-edit-drag-handle"
                  aria-hidden="true"
                  title="Drag to reorder"
                >
                  <DragIndicatorRounded />
                </span>

                <button
                  className="provider-fleet-edit-photo-delete"
                  type="button"
                  aria-label={
                    photo.kind === 'existing'
                      ? `Remove photo ${index + 1}`
                      : `Discard new photo ${index + 1}`
                  }
                  disabled={busy}
                  onClick={() =>
                    photo.kind === 'existing'
                      ? removeExistingPhoto(photo.url)
                      : removePendingPhoto(photo.id)
                  }
                >
                  <DeleteOutlineRounded />
                </button>

                {index === 0 ? (
                  <figcaption>Cover</figcaption>
                ) : photo.kind === 'pending' ? (
                  <figcaption>New</figcaption>
                ) : null}
              </figure>
            ))}

            {photoItems.length === 0 && (
              <div className="provider-fleet-edit-no-photos">
                <DirectionsCarOutlined />
                <strong>No vehicle photos</strong>
                <span>Add clear exterior and interior photos.</span>
              </div>
            )}
          </div>

          <small className="provider-fleet-edit-photo-note">
            Drag photos to change their order. The first photo is the cover.
            New photos and ordering are saved with your changes; removing an
            existing photo happens immediately.
          </small>
        </aside>
      </form>
    </main>
  );
}

function EditSection({
  title,
  description,
  children,
}: {
  title: string;
  description: string;
  children: ReactNode;
}) {
  return (
    <section className="provider-fleet-edit-section">
      <header>
        <h2>{title}</h2>
        <p>{description}</p>
      </header>
      {children}
    </section>
  );
}

function EditField({
  label,
  required = false,
  children,
}: {
  label: string;
  required?: boolean;
  children: ReactNode;
}) {
  return (
    <label className="provider-fleet-edit-field">
      <span>{label}{required && <em>*</em>}</span>
      {children}
    </label>
  );
}

function ReadOnlyDetail({
  label,
  value,
}: {
  label: string;
  value: string | number | undefined;
}) {
  return (
    <div>
      <dt>{label}</dt>
      <dd>{value ?? 'Not provided'}</dd>
    </div>
  );
}

function EditState({
  title,
  message,
  actionLabel,
  onAction,
}: {
  title: string;
  message: string;
  actionLabel: string;
  onAction: () => void;
}) {
  return (
    <div className="provider-fleet-edit-state">
      <DirectionsCarOutlined />
      <h1>{title}</h1>
      <p>{message}</p>
      <button type="button" onClick={onAction}>{actionLabel}</button>
    </div>
  );
}

